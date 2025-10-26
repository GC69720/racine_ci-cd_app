from django.urls import path
from .views import healthz, ping

urlpatterns = [
    path("healthz", healthz, name="healthz"),
    path("ping", ping, name="ping"),
]
