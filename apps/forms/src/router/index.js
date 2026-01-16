import { createRouter, createWebHistory } from "vue-router";
import CtpForm from "../views/CtpForm.vue";

const routes = [
  { path: "/", redirect: "/ctp" },
  { path: "/ctp", name: "CtpForm", component: CtpForm },
];

export default createRouter({
  history: createWebHistory(),
  routes,
});
