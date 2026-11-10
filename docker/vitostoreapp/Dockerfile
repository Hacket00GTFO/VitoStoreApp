FROM nginx:1.29-alpine
# Config servida por el contenedor `vitostoreapp` (compose de VitoStoreApp).
# El contenido (`build/web` de Flutter) se monta como volumen en el compose:
COPY default.conf /etc/nginx/conf.d/default.conf
