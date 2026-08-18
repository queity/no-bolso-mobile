import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Função para fazer upload de uma imagem e retornar a URL dela
  Future<String> uploadReceipt(File imageFile, String userId) async {
    try {
      // Cria um nome único para o arquivo usando a data atual
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();

      // Mantém a extensão original (jpg, png, heic...) pra não gravar tudo
      // como .jpg e o Storage servir o arquivo com o tipo errado.
      final extension = imageFile.path.split('.').last.toLowerCase();

      // Cria o caminho lá no Firebase Storage (ex: receipts/id_do_usuario/123456.jpg)
      Reference ref = _storage.ref().child(
        'receipts/$userId/$fileName.$extension',
      );

      // Faz o upload do arquivo
      UploadTask uploadTask = ref.putFile(imageFile);

      // Espera o upload terminar
      TaskSnapshot snapshot = await uploadTask;

      // Pega o link (URL) da imagem que acabou de subir para salvar no Firestore depois
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Erro ao fazer upload do recibo: $e");
      // Repassa pra tela: se o recibo não subiu, o usuário precisa saber
      // antes da transação ser salva sem o anexo.
      rethrow;
    }
  }

  /// Remove um recibo do Storage a partir da URL que está salva na transação.
  ///
  /// Usado quando o usuário troca ou apaga o anexo de uma transação — sem isso
  /// o arquivo antigo ficaria órfão no bucket para sempre.
  Future<void> deleteReceipt(String downloadUrl) async {
    try {
      await _storage.refFromURL(downloadUrl).delete();
    } catch (e) {
      // Falhar aqui não pode impedir o usuário de salvar a transação — o pior
      // caso é sobrar um arquivo órfão no bucket.
      debugPrint("Erro ao remover o recibo antigo: $e");
    }
  }
}
