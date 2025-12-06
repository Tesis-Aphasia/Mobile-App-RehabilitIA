#############################################
# STAGE 1 — Build Flutter Web
#############################################
FROM ghcr.io/cirruslabs/flutter:latest AS builder

WORKDIR /app

# Copy full repository
COPY . .

# Enable web and build it
RUN flutter config --enable-web
RUN flutter build web --release

#############################################
# STAGE 2 — Serve with Nginx
#############################################
FROM nginx:alpine

# Optional: optimized nginx config for SPA
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the build
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
