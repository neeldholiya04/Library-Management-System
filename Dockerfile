# ---------- Build stage: compile the jar ----------
FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace

COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN ./mvnw -B -q dependency:go-offline

COPY src src
RUN ./mvnw -B -q package -DskipTests

# ---------- Runtime stage: only the JRE and the jar ----------
FROM eclipse-temurin:21-jre
LABEL org.opencontainers.image.source="https://github.com/neeldholiya04/Library-Management-System"

ARG GIT_SHA=unknown
ARG APP_VERSION=dev
ENV GIT_SHA=${GIT_SHA} \
    APP_VERSION=${APP_VERSION}

RUN groupadd --system --gid 10001 app && \
    useradd --system --uid 10001 --gid app --no-create-home app

WORKDIR /app
COPY --from=build /workspace/target/*.jar app.jar

USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]