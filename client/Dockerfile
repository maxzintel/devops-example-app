# syntax=docker/dockerfile:1
# Parent Imnage.
FROM node:12-alpine as build
# Add below back for local dev!
# ENV REACT_APP_BACKEND_URL=http://localhost:3030/
# Modify parent image - add code directory.
WORKDIR /app
COPY . .
# Copy local requirements.txt into code directory.
RUN yarn install && yarn build

# nginx state for serving content
FROM nginx:alpine
# Set working directory to nginx asset directory
WORKDIR /usr/share/nginx/html
# Remove default nginx static assets
RUN rm -rf ./*
# Copy static assets from builder stage
COPY --from=build /app/build .
# Containers run nginx with global directives and daemon off
ENTRYPOINT ["nginx", "-g", "daemon off;"]
