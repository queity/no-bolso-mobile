import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  // `late` pra não tocar o Firebase na hora de criar o StorageService (ex.:
  // em testes de widget que só montam a tela) — só acessa de verdade quando
  // o upload é chamado.
  late final FirebaseStorage _storage = FirebaseStorage.instance;

  // Função para fazer upload de uma imagem e retornar a URL dela
  Future<String?> uploadReceipt(File imageFile, String userId) async {
    try {
      // Cria um nome único para o arquivo usando a data atual
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();

      // Cria o caminho lá no Firebase Storage (ex: receipts/id_do_usuario/123456.jpg)
      Reference ref = _storage.ref().child('receipts/$userId/$fileName.jpg');

      // Faz o upload do arquivo
      UploadTask uploadTask = ref.putFile(imageFile);

      // Espera o upload terminar
      TaskSnapshot snapshot = await uploadTask;

      // Pega o link (URL) da imagem que acabou de subir para salvar no Firestore depois
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Erro ao fazer upload do recibo: $e");
      return null;
    }
  }
}
