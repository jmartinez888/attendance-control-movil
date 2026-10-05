import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'storage_service.dart';

class UsersService {
  // Listar todos los usuarios (Solo ADMIN)
  static Future<List<UserModel>> findAll() async {
    final response = await ApiClient.get(ApiConfig.usersAll);
    if (response is List) {
      return response.map((item) => UserModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // Listar supervisores activos y cupos (Solo ADMIN)
  static Future<Map<String, dynamic>> getSupervisors() async {
    final response = await ApiClient.get(ApiConfig.usersSupervisors);
    return response as Map<String, dynamic>;
  }

  // Revocar cargo de supervisor (Solo ADMIN)
  static Future<Map<String, dynamic>> revokeSupervisor(String id) async {
    final response = await ApiClient.delete(ApiConfig.userRevokeSupervisor(id));
    return response as Map<String, dynamic>;
  }

  // Asignar rol a un usuario (Solo ADMIN)
  static Future<UserModel> assignRole(String id, UserRole role) async {
    final response = await ApiClient.patch(
      ApiConfig.userRole(id),
      body: {'role': role == UserRole.USER ? 'EMPLOYEE' : role.name},
    );
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  // Eliminar usuario de la institución (Solo ADMIN)
  static Future<void> deleteUser(String id) async {
    await ApiClient.delete(ApiConfig.userById(id));
  }

  // Desvincular celular del usuario para permitir registro en un nuevo equipo (Solo ADMIN)
  static Future<void> unbindDevice(String id) async {
    await ApiClient.delete(ApiConfig.userDevice(id));
  }

  // Actualizar datos de cualquier colaborador (ADMIN o SUPERVISOR)
  static Future<UserModel> updateUser(String id, Map<String, dynamic> data) async {
    final response = await ApiClient.patch(
      ApiConfig.userById(id),
      body: data,
    );
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  // Actualizar perfil del usuario conectado
  static Future<UserModel> updateProfile(Map<String, dynamic> data) async {
    final response = await ApiClient.patch(ApiConfig.usersMe, body: data);
    final user = UserModel.fromJson(response as Map<String, dynamic>);
    await StorageService.updateCurrentUser(user);
    return user;
  }

  // Subir foto de perfil en Base64
  static Future<String> uploadPhotoBase64(String base64Image) async {
    final response = await ApiClient.post(
      ApiConfig.uploadPhotoBase64,
      body: {'image_base64': base64Image},
    );
    final photoUrl = response['photo_url']?.toString() ?? '';
    final currentUser = StorageService.currentUserNotifier.value;
    if (currentUser != null && photoUrl.isNotEmpty) {
      await StorageService.updateCurrentUser(currentUser.copyWith(photoUrl: photoUrl));
    }
    return photoUrl;
  }
}
