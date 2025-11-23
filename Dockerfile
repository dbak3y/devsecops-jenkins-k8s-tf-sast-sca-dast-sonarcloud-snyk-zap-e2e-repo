FROM maven:3.8-jdk-8 AS builder
COPY . /usr/src/easybuggy/
WORKDIR /usr/src/easybuggy/
RUN mvn -B package

# Pick one of the below:

# Option A (AdoptOpenJDK):
FROM adoptopenjdk/openjdk8:jdk8u202-b08-alpine-slim
# Option B (Microsoft Build):
# FROM mcr.microsoft.com/openjdk/jdk:8-azurelinux
# Option C (Official but deprecated):
# FROM openjdk:8-jre-slim

COPY --from=builder /usr/src/easybuggy/target/easybuggy.jar /
CMD ["java", "-XX:MaxMetaspaceSize=128m", … , "-jar", "easybuggy.jar"]
