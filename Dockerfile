# ---------- Build stage ----------
FROM m.daocloud.io/docker.io/library/maven:3.9.11-eclipse-temurin-17 AS builder

WORKDIR /app

COPY pom.xml .
COPY src ./src

RUN mvn -B -DskipTests package


# ---------- Runtime stage ----------
FROM m.daocloud.io/docker.io/library/eclipse-temurin:17-jre

WORKDIR /app

COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]