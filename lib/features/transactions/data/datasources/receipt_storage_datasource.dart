import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Acesso direto ao Firebase Storage para os recibos (antigo
/// `StorageService`). Usado só pelo `ReceiptRepositoryImpl`.
class ReceiptStorageDatasource {
  ReceiptStorageDatasource({FirebaseStorage? storage})
    : _storageOverride = storage;

  final FirebaseStorage? _storageOverride;
  // `late` pra não tocar o Firebase ao montar telas em testes de widget.
  late final FirebaseStorage _storage =
      _storageOverride ?? FirebaseStorage.instance;

  /// Faz upload da imagem em `receipts/{userId}/{timestamp}.{ext}` e retorna
  /// a URL de download.
  Future<String> upload(File imageFile, String userId) async {
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();

      // Mantém a extensão original (jpg, png, heic...) pra não gravar tudo
      // como .jpg e o Storage servir o arquivo com o tipo errado.
      final extension = imageFile.path.split('.').last.toLowerCase();

      final ref = _storage.ref().child('receipts/$userId/$fileName.$extension');
      final snapshot = await ref.putFile(imageFile);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Erro ao fazer upload do recibo: $e");
      // Se o recibo não subiu, o usuário precisa saber antes da transação
      // ser salva sem o anexo.
      rethrow;
    }
  }

  /// Remove um recibo a partir da URL salva na transação.
  Future<void> delete(String downloadUrl) async {
    try {
      await _storage.refFromURL(downloadUrl).delete();
    } catch (e) {
      // Falhar aqui não pode impedir o usuário de salvar a transação — o pior
      // caso é sobrar um arquivo órfão no bucket.
      debugPrint("Erro ao remover o recibo antigo: $e");
    }
  }
}
