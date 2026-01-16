import { createRouter, createWebHistory } from "vue-router";
import EventView from "@/views/EventView.vue";
import CTPLeadersView from "@/views/CTPLeadersView.vue";

const LATEST_EVENT_ID = "52"; // ← change when a new event is live

const routes = [
  {
    path: "/",
    redirect: `/events/${LATEST_EVENT_ID}`,
  },
  {
    path: "/events/:eventId",
    name: "Event",
    component: EventView,
  },
  {
    path: "/events/:eventId/ctp",
    name: "EventCTP",
    component: CTPLeadersView,
  },
];

export default createRouter({
  history: createWebHistory(),
  routes,
});
