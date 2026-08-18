moved {
  from = kubernetes_stateful_set.onify-hub-app
  to   = kubernetes_stateful_set.onify-hub-app[0]
}

moved {
  from = kubernetes_service.onify-hub-app
  to   = kubernetes_service.onify-hub-app[0]
}
