import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Bloco de anexo de recibo usado no formulário de transação.
///
/// Ele não conversa com o Firebase nem com o `ImagePicker` — só mostra o que
/// existe hoje e avisa a tela do que o usuário pediu. Quem escolhe a imagem e
/// faz o upload é a tela, o que deixa este widget reaproveitável (o detalhe de
/// uma transação, por exemplo, pode usar o mesmo preview em modo somente
/// leitura passando `enabled: false`).
class ReceiptPicker extends StatelessWidget {
  const ReceiptPicker({
    super.key,
    this.localFile,
    this.remoteUrl,
    this.enabled = true,
    required this.onPick,
    required this.onRemove,
  });

  /// Imagem recém-escolhida no aparelho, ainda não enviada ao Storage.
  final File? localFile;

  /// Recibo que já está salvo no Firebase Storage (modo edição).
  final String? remoteUrl;

  /// Desliga os botões enquanto a tela está salvando.
  final bool enabled;

  final ValueChanged<ImageSource> onPick;
  final VoidCallback onRemove;

  bool get _hasReceipt => localFile != null || remoteUrl != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Recibo (opcional)',
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (_hasReceipt)
          _ReceiptPreview(
            localFile: localFile,
            remoteUrl: remoteUrl,
            enabled: enabled,
            onRemove: onRemove,
          )
        else
          _EmptyReceiptSlot(enabled: enabled, onPick: onPick),
        if (_hasReceipt) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: enabled
                      ? () => onPick(ImageSource.camera)
                      : null,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Câmera'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: enabled
                      ? () => onPick(ImageSource.gallery)
                      : null,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Galeria'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Área tracejada mostrada quando ainda não há nenhum recibo anexado.
class _EmptyReceiptSlot extends StatelessWidget {
  const _EmptyReceiptSlot({required this.enabled, required this.onPick});

  final bool enabled;
  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: colorScheme.onSurfaceVariant,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Anexe a foto do comprovante',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: enabled ? () => onPick(ImageSource.camera) : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Câmera'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: enabled ? () => onPick(ImageSource.gallery) : null,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Galeria'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Miniatura do recibo já anexado, com o botão de remover por cima.
class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({
    required this.localFile,
    required this.remoteUrl,
    required this.enabled,
    required this.onRemove,
  });

  final File? localFile;
  final String? remoteUrl;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: localFile != null
                // A imagem local tem prioridade: é a que o usuário acabou de
                // escolher e ainda não foi enviada.
                ? Image.file(localFile!, fit: BoxFit.cover)
                : Image.network(
                    remoteUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Remover recibo',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
