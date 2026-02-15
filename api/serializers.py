from rest_framework import serializers
from django.contrib.auth import authenticate
from .models import User, PhotoDiary, SOSAlert


class RegisterSerializer(serializers.ModelSerializer):
    """Serializer for user registration — matches signup_screen.dart fields"""
    password = serializers.CharField(write_only=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = [
            'email', 'full_name', 'mobile', 'password', 'confirm_password',
            'blood_group', 'medical_condition',
            'emergency_contact_1', 'emergency_contact_2',
        ]

    def validate(self, data):
        if data['password'] != data['confirm_password']:
            raise serializers.ValidationError({'confirm_password': 'Passwords do not match.'})
        return data

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        password = validated_data.pop('password')
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user


class LoginSerializer(serializers.Serializer):
    """Serializer for user login — matches login_screen.dart fields"""
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        user = authenticate(username=data['email'], password=data['password'])
        if not user:
            raise serializers.ValidationError('Invalid email or password.')
        if not user.is_active:
            raise serializers.ValidationError('Account is disabled.')
        data['user'] = user
        return data


class UserProfileSerializer(serializers.ModelSerializer):
    """Serializer for viewing and editing user profile — matches profile_edit_screen.dart"""
    profile_image_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'full_name', 'mobile',
            'blood_group', 'medical_condition',
            'emergency_contact_1', 'emergency_contact_2',
            'location', 'profile_image', 'profile_image_url',
            'date_joined',
        ]
        read_only_fields = ['id', 'email', 'date_joined', 'profile_image_url']

    def get_profile_image_url(self, obj):
        request = self.context.get('request')
        if obj.profile_image and request:
            return request.build_absolute_uri(obj.profile_image.url)
        return None


class UpdateProfileSerializer(serializers.ModelSerializer):
    """Serializer for updating user profile"""
    class Meta:
        model = User
        fields = [
            'full_name', 'mobile', 'blood_group', 'medical_condition',
            'emergency_contact_1', 'emergency_contact_2',
            'location', 'profile_image',
        ]


class PhotoDiarySerializer(serializers.ModelSerializer):
    """Serializer for photo diary entries — matches photo_diary_screen.dart"""
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = PhotoDiary
        fields = [
            'id', 'image', 'image_url', 'caption',
            'location', 'latitude', 'longitude', 'created_at',
        ]
        read_only_fields = ['id', 'created_at', 'image_url']

    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image and request:
            return request.build_absolute_uri(obj.image.url)
        return None


class SOSAlertSerializer(serializers.ModelSerializer):
    """Serializer for SOS emergency alerts — matches _sendSOSSignal() in tourmate_dashboard.dart"""
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    user_phone = serializers.CharField(source='user.mobile', read_only=True)
    user_blood_group = serializers.CharField(source='user.blood_group', read_only=True)
    user_medical_condition = serializers.CharField(source='user.medical_condition', read_only=True)
    emergency_contact_1 = serializers.CharField(source='user.emergency_contact_1', read_only=True)
    emergency_contact_2 = serializers.CharField(source='user.emergency_contact_2', read_only=True)

    class Meta:
        model = SOSAlert
        fields = [
            'id', 'latitude', 'longitude', 'location_description',
            'message', 'status', 'created_at',
            'user_name', 'user_phone', 'user_blood_group',
            'user_medical_condition', 'emergency_contact_1', 'emergency_contact_2',
        ]
        read_only_fields = [
            'id', 'status', 'created_at',
            'user_name', 'user_phone', 'user_blood_group',
            'user_medical_condition', 'emergency_contact_1', 'emergency_contact_2',
        ]
