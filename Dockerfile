# Use latest stable channel SDK.
FROM dart:stable AS build

# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy app source code (except anything in .dockerignore) and AOT compile app.
COPY . .
RUN dart pub get
RUN dart compile exe bin/dart_donation_bot.dart -o bin/dart_donation_bot

# Build minimal serving image from AOT-compiled `/dart_donation_bot`
# and the pre-built AOT-runtime in the `/runtime/` directory of the base image.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/dart_donation_bot /app/bin/

# Start dart_donation_bot.
CMD ["/app/bin/dart_donation_bot"]
