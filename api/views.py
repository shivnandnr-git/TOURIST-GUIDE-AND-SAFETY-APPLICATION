from rest_framework import status, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate

from .models import User, PhotoDiary, SOSAlert
from .serializers import (
    RegisterSerializer, LoginSerializer,
    UserProfileSerializer, UpdateProfileSerializer,
    PhotoDiarySerializer, SOSAlertSerializer,
)


def get_tokens_for_user(user):
    """Generate JWT access and refresh tokens for a user"""
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }


# ─────────────────────────────────────────────
#  AUTH ENDPOINTS
# ─────────────────────────────────────────────

class RegisterView(APIView):
    """
    POST /api/auth/register/
    Register a new tourist account.
    Body: email, full_name, mobile, password, confirm_password,
          blood_group, medical_condition (optional),
          emergency_contact_1, emergency_contact_2 (optional)
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            tokens = get_tokens_for_user(user)
            return Response({
                'message': 'Account created successfully.',
                'user': UserProfileSerializer(user, context={'request': request}).data,
                'tokens': tokens,
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LoginView(APIView):
    """
    POST /api/auth/login/
    Login with email and password.
    Body: email, password
    Returns: user profile + JWT tokens
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.validated_data['user']
            tokens = get_tokens_for_user(user)
            return Response({
                'message': 'Login successful.',
                'user': UserProfileSerializer(user, context={'request': request}).data,
                'tokens': tokens,
            }, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LogoutView(APIView):
    """
    POST /api/auth/logout/
    Blacklist refresh token to log out.
    Body: refresh (token string)
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data.get('refresh')
            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response({'message': 'Logged out successfully.'}, status=status.HTTP_200_OK)
        except Exception:
            return Response({'error': 'Invalid token.'}, status=status.HTTP_400_BAD_REQUEST)


# ─────────────────────────────────────────────
#  PROFILE ENDPOINTS
# ─────────────────────────────────────────────

class ProfileView(APIView):
    """
    GET  /api/profile/        — Fetch logged-in user's profile
    PUT  /api/profile/        — Update profile fields
    PATCH /api/profile/       — Partial update
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        serializer = UserProfileSerializer(request.user, context={'request': request})
        return Response(serializer.data)

    def put(self, request):
        serializer = UpdateProfileSerializer(
            request.user, data=request.data, partial=False
        )
        if serializer.is_valid():
            serializer.save()
            return Response({
                'message': 'Profile updated successfully.',
                'user': UserProfileSerializer(request.user, context={'request': request}).data,
            })
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def patch(self, request):
        serializer = UpdateProfileSerializer(
            request.user, data=request.data, partial=True
        )
        if serializer.is_valid():
            serializer.save()
            return Response({
                'message': 'Profile updated successfully.',
                'user': UserProfileSerializer(request.user, context={'request': request}).data,
            })
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ─────────────────────────────────────────────
#  PHOTO DIARY ENDPOINTS
# ─────────────────────────────────────────────

class PhotoDiaryListCreateView(APIView):
    """
    GET  /api/photos/        — Get all photos for logged-in user
    POST /api/photos/        — Upload a new photo
    Query params: ?search=   — Filter by caption or location
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        photos = PhotoDiary.objects.filter(user=request.user)
        search = request.query_params.get('search', '')
        if search:
            photos = photos.filter(
                caption__icontains=search
            ) | PhotoDiary.objects.filter(
                user=request.user,
                location__icontains=search
            )
            photos = photos.distinct()
        serializer = PhotoDiarySerializer(photos, many=True, context={'request': request})
        return Response(serializer.data)

    def post(self, request):
        serializer = PhotoDiarySerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save(user=request.user)
            return Response({
                'message': 'Photo added to diary.',
                'photo': serializer.data,
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class PhotoDiaryDetailView(APIView):
    """
    GET    /api/photos/<id>/   — Get a specific photo
    DELETE /api/photos/<id>/   — Delete a photo
    """
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        try:
            return PhotoDiary.objects.get(pk=pk, user=user)
        except PhotoDiary.DoesNotExist:
            return None

    def get(self, request, pk):
        photo = self.get_object(pk, request.user)
        if not photo:
            return Response({'error': 'Photo not found.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = PhotoDiarySerializer(photo, context={'request': request})
        return Response(serializer.data)

    def delete(self, request, pk):
        photo = self.get_object(pk, request.user)
        if not photo:
            return Response({'error': 'Photo not found.'}, status=status.HTTP_404_NOT_FOUND)
        photo.image.delete(save=False)  # Delete file from disk
        photo.delete()
        return Response({'message': 'Photo deleted.'}, status=status.HTTP_204_NO_CONTENT)


# ─────────────────────────────────────────────
#  SOS EMERGENCY ENDPOINTS
# ─────────────────────────────────────────────

class SOSCreateView(APIView):
    """
    POST /api/sos/
    Send an SOS emergency alert.
    Body: latitude, longitude, location_description (optional), message (optional)
    Returns full user medical profile + contact info for emergency responders.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = SOSAlertSerializer(data=request.data)
        if serializer.is_valid():
            sos = serializer.save(user=request.user)
            # Return complete data including user medical info
            response_data = SOSAlertSerializer(sos, context={'request': request}).data
            return Response({
                'message': 'SOS alert sent. Help is on the way.',
                'alert': response_data,
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class SOSHistoryView(APIView):
    """
    GET /api/sos/history/
    Get SOS alert history for the logged-in user.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        alerts = SOSAlert.objects.filter(user=request.user)
        serializer = SOSAlertSerializer(alerts, many=True, context={'request': request})
        return Response(serializer.data)
