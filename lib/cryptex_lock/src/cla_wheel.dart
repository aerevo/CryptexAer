import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // Wajib untuk Haptic

class ClaWheel extends StatelessWidget {
  final List<String> items;
  final ValueChanged<int> onChanged;

  const ClaWheel({super.key, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: 50, // Bagi lebar sikit supaya jari selesa
      child: CupertinoPicker(
        itemExtent: 40,
        squeeze: 1.2, // Rapatkan sikit supaya nampak padat
        useMagnifier: true,
        magnification: 1.1,
        onSelectedItemChanged: (index) {
          // --- SUNTIKAN ROH 1: GETARAN ---
          HapticFeedback.selectionClick(); 
          onChanged(index);
        },
        children: items.map((e) => Center(
          child: Text(
            e, 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)
          )
        )).toList(),
      ),
    );
  }
}
