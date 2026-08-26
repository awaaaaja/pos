import { createApp } from "vue";
import { createPinia } from "pinia";
import App from "./App.vue";
import router from "./router";
import { setupAuthMiddleware } from "./modules/auth/composables/useAuthMiddleware";
import "./style.css";

const app = createApp(App);
const pinia = createPinia();

app.use(pinia);
app.use(router);

setupAuthMiddleware(router);

app.mount("#app");
