import 'package:flutter/material.dart';

class LoadingButton extends StatelessWidget {
  final String label;
  final String? loadingLabel;
  final bool isLoading;
  final VoidCallback? onPressed;

  const LoadingButton({
    super.key,
    required this.label,
    this.loadingLabel,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                if (loadingLabel != null) ...[
                  const SizedBox(width: 10),
                  Text(loadingLabel!),
                ],
              ],
            )
          : Text(label),
    );
  }
}
