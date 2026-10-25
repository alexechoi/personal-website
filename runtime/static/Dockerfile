# Shared image for every `"type": "static"` project.
# scripts/deploy.sh copies the project's files into ./site next to this file.
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/
EXPOSE 8080
