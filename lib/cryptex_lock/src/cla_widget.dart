@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Container(
        width: 300, // ⭐ FIXED WIDTH DULU
        height: 300, // ⭐ FIXED HEIGHT DULU
        color: Colors.red, // ⭐ DEBUG COLOR
      ),
    ),
  );
}
