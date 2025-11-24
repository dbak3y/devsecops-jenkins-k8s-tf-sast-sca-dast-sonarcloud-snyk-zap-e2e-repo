# ===========================
# Stage 1: Build with Maven
# ===========================
FROM maven:3.9.6-eclipse-temurin-8 AS builder

WORKDIR /usr/src/easybuggy

# Copy full project and build WAR
COPY . .
RUN mvn clean package -DskipTests

# ===========================
# Stage 2: Runtime with Tomcat
# ===========================
FROM tomcat:9.0-jdk8-temurin

WORKDIR /usr/local/tomcat

# Remove default ROOT application
RUN rm -rf webapps/ROOT webapps/ROOT.war

# Copy the built WAR from builder stage
COPY --from=builder /usr/src/easybuggy/target/ROOT.war webapps/ROOT.war

# App runs on 8080 inside container
EXPOSE 8080

# Run Tomcat
CMD ["catalina.sh", "run"]
