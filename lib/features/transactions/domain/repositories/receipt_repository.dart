/// Contrato de armazenamento dos recibos anexados às transações.
abstract interface class ReceiptRepository {
  /// Envia o arquivo em [filePath] e devolve a URL para salvar na transação.
  Future<String> upload({required String filePath, required String userId});

  /// Remove um recibo a partir da URL salva na transação. Não lança erro:
  /// no pior caso sobra um arquivo órfão.
  Future<void> delete(String url);
}
