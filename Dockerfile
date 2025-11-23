# ===========================
# Stage 1: Build with Maven
# ===========================
FROM maven:3.8-jdk-8 AS builder

WORKDIR /usr/src/easybuggy

# Copy everything and build
COPY . .
RUN mvn -B package

# ===========================
# Stage 2: Runtime image
# ===========================
FROM adoptopenjdk/openjdk8:jdk8u202-b08-alpine-slim

WORKDIR /app

# Copy the jar from the builder stage
# Make sure the jar name matches what Maven produces
COPY --from=builder /usr/src/easybuggy/target/easybuggy-1.0-SNAPSHOT.jar ./easybuggy.jar

# Your original CMD with JVM options
CMD ["java",
     "-XX:MaxMetaspaceSize=128m",
     "-Xloggc:logs/gc_%p_%t.log",
     "-Xmx256m",
     "-XX:MaxDirectMemorySize=90m",
     "-XX:+UseSerialGC",
     "-XX:+PrintHeapAtGC",
     "-XX:+PrintGCDetails",
     "-XX:+PrintGCDateStamps",
     "-XX:+UseGCLogFileRotation",
     "-XX:NumberOfGCLogFiles=5",
     "-XX:GCLogFileSize=10M",
     "-XX:GCTimeLimit=15",
     "-XX:GCHeapFreeLimit=50",
     "-XX:+HeapDumpOnOutOfMemoryError",
     "-XX:HeapDumpPath=logs/",
     "-XX:ErrorFile=logs/hs_err_pid%p.log",
     "-agentlib:jdwp=transport=dt_socket,server=y,address=9009,suspend=n",
     "-Dderby.stream.error.file=logs/derby.log",
     "-Dderby.infolog.append=true",
     "-Dderby.language.logStatementText=true",
     "-Dderby.locks.deadlockTrace=true",
     "-Dderby.locks.monitor=true",
     "-Dderby.storage.rowLocking=true",
     "-Dcom.sun.management.jmxremote",
     "-Dcom.sun.management.jmxremote.port=7900",
     "-Dcom.sun.management.jmxremote.ssl=false",
     "-Dcom.sun.management.jmxremote.authenticate=false",
     "-ea",
     "-jar",
     "easybuggy.jar"]
