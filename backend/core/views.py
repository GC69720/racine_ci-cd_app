from django.http import JsonResponse

def healthz(request):
    return JsonResponse({"status": "ok"})

def ping(request):
    return JsonResponse({"message": "pong"})
