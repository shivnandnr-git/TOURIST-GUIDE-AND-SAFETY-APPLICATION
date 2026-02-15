from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, PhotoDiary, SOSAlert


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['email', 'full_name', 'mobile', 'blood_group', 'date_joined']
    list_filter = ['blood_group', 'is_active', 'is_staff']
    search_fields = ['email', 'full_name', 'mobile']
    ordering = ['-date_joined']

    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal Info', {'fields': ('full_name', 'mobile', 'profile_image', 'location')}),
        ('Medical Info', {'fields': ('blood_group', 'medical_condition')}),
        ('Emergency Contacts', {'fields': ('emergency_contact_1', 'emergency_contact_2')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'full_name', 'mobile', 'blood_group',
                       'emergency_contact_1', 'password1', 'password2'),
        }),
    )


@admin.register(PhotoDiary)
class PhotoDiaryAdmin(admin.ModelAdmin):
    list_display = ['user', 'caption', 'location', 'created_at']
    list_filter = ['created_at']
    search_fields = ['caption', 'location', 'user__full_name']
    ordering = ['-created_at']


@admin.register(SOSAlert)
class SOSAlertAdmin(admin.ModelAdmin):
    list_display = ['user', 'status', 'latitude', 'longitude', 'created_at']
    list_filter = ['status', 'created_at']
    search_fields = ['user__full_name', 'user__mobile']
    ordering = ['-created_at']
