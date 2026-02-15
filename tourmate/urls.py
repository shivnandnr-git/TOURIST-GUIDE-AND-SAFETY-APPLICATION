from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    # ── Auth ──────────────────────────────────────
    path('auth/register/', views.RegisterView.as_view(), name='register'),
    path('auth/login/',    views.LoginView.as_view(),    name='login'),
    path('auth/logout/',   views.LogoutView.as_view(),   name='logout'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # ── Profile ───────────────────────────────────
    path('profile/', views.ProfileView.as_view(), name='profile'),

    # ── Photo Diary ───────────────────────────────
    path('photos/',      views.PhotoDiaryListCreateView.as_view(), name='photos'),
    path('photos/<int:pk>/', views.PhotoDiaryDetailView.as_view(), name='photo-detail'),

    # ── SOS Emergency ─────────────────────────────
    path('sos/',         views.SOSCreateView.as_view(),  name='sos'),
    path('sos/history/', views.SOSHistoryView.as_view(), name='sos-history'),
]
