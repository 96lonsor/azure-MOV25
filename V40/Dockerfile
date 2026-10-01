# Bygg i molnet:
#   az acr build --registry novatrixacr --image novatrix-app:v1 .
# Kör i ACI:
#   az container create ... (se README)
FROM nginx:alpine

# Kopiera Novatrix sida till nginx webbmapp
COPY index.html /usr/share/nginx/html/index.html

# Containern lyssnar på port 80
EXPOSE 80
