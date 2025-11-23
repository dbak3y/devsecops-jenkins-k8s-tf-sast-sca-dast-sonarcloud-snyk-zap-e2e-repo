# ===========================
# Stage 1: Build with Maven
# ===========================
FROM maven:3.8-jdk-8 AS builder

WORKDIR /usr/src/easybuggy

# Copy the source code and build the WAR
COPY . .
RUN mvn -B package

# ===========================
# Stage 2: Runtime with Tomcat
# ===========================
FROM tomcat:9.0-jdk8-openjdk-slim

WORKDIR /usr/local/tomcat

# Remove default ROOT webapp
RUN rm -rf webapps/ROOT*

# Copy the WAR from the builder stage
COPY --from=builder /usr/src/easybuggy/target/ROOT.war webapps/ROOT.war

# Expose the port configured in EasyBuggy
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]
