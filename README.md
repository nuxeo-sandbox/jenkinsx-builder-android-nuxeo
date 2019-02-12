# Jenkins X Android Builder

This is a Jenkins X Builder (aka [Pod Template](https://jenkins-x.io/architecture/pod-templates/)) to build a Docker image that can be used in the Jenkins X platform to build an Android application.

The image also includes Node.js and Yarn as its primary purpose is to build the Nuxeo Android application.

## Build the Builder

To add a Jenkins X pipeline building and pushing the Docker image, import this repository into your Jenkins X platform:
```
jx import . --no-draft=true
```

Using `--no-draft` to disable Draft from trying to default a Dockerfile and Helm Chart.

## Create the Required Secrets

To build a signed APK you need the Nuxeo Java keystore and a `gradle.properties` file with the following properties:
```
org.gradle.daemon=true
org.gradle.jvmargs=-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -Xms2048m -Xmx2048m
NUXEO_RELEASE_STORE_FILE=/home/jenkins/keystores
NUXEO_RELEASE_KEY_ALIAS=my-key-alias
NUXEO_RELEASE_STORE_PASSWORD=*****
NUXEO_RELEASE_KEY_PASSWORD=*****
```

See https://stackoverflow.com/questions/38967991/why-are-my-gradle-builds-dying-with-exit-code-137/51364393#51364393 about the `-XX:+UnlockExperimentalVMOptions` and `-XX:+UseCGroupMemoryLimitForHeap` JVM arguments for the Gradle Daemon that prevent the kernel's Out of Memory Killer from forcibly killing a Gradle Daemon process and terminating the build with exit code 137.

Also, we're setting the memory allocated to the Gradle Daemon high enough to comply with Gradle's recommendations, otherwise we would get:
```
To run dex in process, the Gradle daemon needs a larger heap.
It currently has 1024 MB.
For faster builds, increase the maximum heap size for the Gradle daemon to at least 1536 MB.
```
It also avoids the Gradle Daemon to get stuck with these logs:
```
[DEBUG] [org.gradle.launcher.daemon.server.Daemon] DaemonExpirationPeriodicCheck running
[DEBUG] [org.gradle.cache.internal.DefaultFileLockManager] Waiting to acquire shared lock on daemon addresses registry.
[DEBUG] [org.gradle.cache.internal.DefaultFileLockManager] Lock acquired.
[DEBUG] [org.gradle.cache.internal.DefaultFileLockManager] Releasing lock on daemon addresses registry.
[DEBUG] [org.gradle.launcher.daemon.server.Daemon] DaemonExpirationPeriodicCheck running
[DEBUG] [org.gradle.cache.internal.DefaultFileLockManager] Waiting to acquire shared lock on daemon addresses registry.
[DEBUG] [org.gradle.cache.internal.DefaultFileLockManager] Lock acquired.
[DEBUG] [org.gradle.cache.internal.DefaultFileLockManager] Releasing lock on daemon addresses registry.
```

See below about the `NUXEO_RELEASE_STORE_FILE` property value.

Since they contain sensitive information, these files must be stored as Kubernetes Secrets:
```
kubectl create secret generic gradle-config-secret --from-file=/path/to/my/gradle.properties

kubectl create secret generic nuxeo-java-keystore --from-file=/path/to/my/nuxeo.jks
```

## Install the Builder 

You can install your builder either when you install Jenkins X or update it.

Create a file called `myvalues.yaml` in your `~/.jx` folder with the following content:
```
jenkins:
  Agent:
    PodTemplates:
      Android:
        Name: builder-android-nuxeo
        Label: builder-android-nuxeo
        DevPodPorts: 5005, 8080
        volumes:
        - type: Secret
          secretName: gradle-config-secret
          mountPath: /home/jenkins/.gradle
        - type: Secret
          secretName: nuxeo-java-keystore
          mountPath: /home/jenkins/keystores
        - type: Secret
          secretName: jenkins-docker-cfg
          mountPath: /home/jenkins/.docker
        EnvVars:
          JENKINS_URL: http://jenkins:8080
          _JAVA_OPTIONS: '-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -Dsun.zip.disableMemoryMapping=true -XX:+UseParallelGC -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10 -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -Xms1024m -Xmx1024m'
          GIT_COMMITTER_EMAIL: jenkins-x@googlegroups.com
          GIT_AUTHOR_EMAIL: jenkins-x@googlegroups.com
          GIT_AUTHOR_NAME: jenkins-x-bot
          GIT_COMMITTER_NAME: jenkins-x-bot
          XDG_CONFIG_HOME: /home/jenkins
          DOCKER_CONFIG: /home/jenkins/.docker/
        ServiceAccount: jenkins
        Containers:
          Jnlp:
            Image: jenkinsci/jnlp-slave:3.27-1
            RequestCpu: "100m"
            RequestMemory: "128Mi"
            Args: '${computer.jnlpmac} ${computer.name}'
          android-nuxeo:
            Image: <DOCKER_REGISTRY_IP>:<DOCKER_REGISTRY_PORT>/nuxeo-sandbox/builder-android-nuxeo 
            Privileged: true
            AlwaysPullImage: true
            RequestCpu: "500m"
            RequestMemory: "2048Mi"
            LimitCpu: "1"
            LimitMemory: "4096Mi"
            Command: "/bin/sh -c"
            Args: "cat"
            Tty: true
```

The `gradle.properties` file must be in the `$USER_HOME/.gradle` directory. The pipelines are executed as `root`, yet the `gradle-config-secret` cannot be mounted as a volume in `/root/.gradle` since the filesystem on which a secret is mounted is read-only and Gradle needs to write in `$USER_HOME/.gradle` at build time. Therefore the `gradle-config-secret` is mounted as a volume in `/home/jenkins/.gradle` and a symlink is created in the [Dockerfile](Dockerfile) to make `/root/.gradle/gradle.properties` point to `/home/jenkins/.gradle/gradle.properties`.

The `mountPath` for the `nuxeo-java-keystore` secret must match the value of the `NUXEO_RELEASE_STORE_FILE` property in the `gradle.properties` file stored as a secret, here: `/home/jenkins/keystores`.

Replace the Docker registry IP and port according to the output of the following command:
```
$ kubectl get svc
NAME                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
...
jenkins-x-docker-registry       ClusterIP   10.19.254.160   <none>        5000/TCP    2h
```

Setting `AlwaysPullImage: true` ensures to always use the latest build of the Docker image.

The `LimitMemory` is set to ensure enough available memory for the Gradle Daemon as mentioned above.

Proceed with the Jenkins X installation, the builder will be automatically added to the platform:
```
jx install --default-admin-password=<PASSWORD> --namespace=<NAMESPACE> --no-tiller
```

When Jenkins X is updated you should get a message like:
```
Using local value overrides file ~/.jx/myvalues.yaml
```

You can always upgrade the Jenkins X platform after having modified `~/.jx/myvalues.yaml` by running:
```
jx upgrade platform --namespace=fit --always-upgrade=true --batch-mode
```

## Use the Builder

Now that your builder was installed in Jenkins X, you can easily reference it in a `Jenkinsfile`:
```
pipeline {
    agent {
        label "builder-android-nuxeo"
    }
    stages {
        stage('Build') {
            when {
                branch 'master'
            }
            steps {
                container('mybuilder') {
                    // your steps
                }
            }
        }
    }
    post {
        always {
            cleanWs()
        }
    }
}
```
