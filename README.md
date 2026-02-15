# TourMate Backend — Django REST API

Backend for the **Tourist Guide and Safety Mobile Application** built with Python Django + Django REST Framework.

---

## Project Structure

```
tourmate_backend/
├── manage.py
├── requirements.txt
├── api_service.dart          ← Copy this to your Flutter project: lib/services/
├── tourmate/
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
└── api/
    ├── models.py             ← User, PhotoDiary, SOSAlert
    ├── serializers.py
    ├── views.py
    ├── urls.py
    └── admin.py
```

---

## Setup Instructions

### 1. Install Python dependencies

```bash
cd tourmate_backend
pip install -r requirements.txt
```

### 2. Run migrations

```bash
python manage.py makemigrations
python manage.py migrate
```

### 3. Create admin superuser (optional)

```bash
python manage.py createsuperuser
```

### 4. Start the server

```bash
python manage.py runserver 0.0.0.0:8000
```

The API will be available at `http://localhost:8000/api/`

---

## API Endpoints

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| POST | `/api/auth/register/` | ❌ | Register new tourist |
| POST | `/api/auth/login/` | ❌ | Login, returns JWT tokens |
| POST | `/api/auth/logout/` | ✅ | Logout, blacklist token |
| POST | `/api/auth/token/refresh/` | ❌ | Refresh access token |
| GET | `/api/profile/` | ✅ | Get user profile |
| PATCH | `/api/profile/` | ✅ | Update user profile |
| GET | `/api/photos/` | ✅ | Get all diary photos |
| POST | `/api/photos/` | ✅ | Upload new photo |
| DELETE | `/api/photos/<id>/` | ✅ | Delete a photo |
| POST | `/api/sos/` | ✅ | Send SOS emergency alert |
| GET | `/api/sos/history/` | ✅ | Get SOS history |

---

## Flutter Integration

### Step 1: Copy the service file
Copy `api_service.dart` into your Flutter project at:
```
lib/services/api_service.dart
```

### Step 2: Add dependencies to pubspec.yaml
```yaml
dependencies:
  http: ^1.1.0
  shared_preferences: ^2.2.0
```

### Step 3: Set the correct base URL in api_service.dart
```dart
// Android emulator
static const String baseUrl = 'http://10.0.2.2:8000/api';

// iOS simulator
static const String baseUrl = 'http://127.0.0.1:8000/api';

// Real Android/iOS device (use your computer's local IP)
static const String baseUrl = 'http://192.168.1.xxx:8000/api';
```

### Step 4: Update login_screen.dart
Replace the `_login()` method with:
```dart
void _login() async {
  if (_formKey.currentState!.validate()) {
    final result = await ApiService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (result['status'] == 200) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const TourMateDashboard(locationPermissionGranted: false),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['data']['non_field_errors']?[0] ?? 'Login failed')),
      );
    }
  }
}
```

### Step 5: Update signup_screen.dart
Replace the `_signup()` method call with:
```dart
void _signup() async {
  if (_formKey.currentState!.validate()) {
    final result = await ApiService.register(
      fullName: _fullNameController.text,
      email: _emailController.text,
      mobile: _mobileController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      bloodGroup: _bloodGroupController.text,
      medicalCondition: _medicalConditionController.text,
      emergencyContact1: _emergencyContact1Controller.text,
      emergencyContact2: _emergencyContact2Controller.text,
    );
    if (result['status'] == 201) {
      _showLocationPermissionDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed. Please try again.')),
      );
    }
  }
}
```

### Step 6: Update _sendSOSSignal() in tourmate_dashboard.dart
```dart
Future<void> _sendSOSSignal() async {
  // ... show loading dialog ...
  final result = await ApiService.sendSOS(
    latitude: 9.9312,   // Replace with real GPS coordinates
    longitude: 76.2673,
    locationDescription: _userData['location'],
    message: 'Emergency SOS triggered.',
  );
  Navigator.pop(context); // close loading
  if (result['status'] == 201) {
    // show success dialog
  }
}
```

---

## Admin Panel
Visit `http://localhost:8000/admin/` to manage users, photos, and SOS alerts.
