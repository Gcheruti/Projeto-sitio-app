# OCR de cupom (google_mlkit_text_recognition): o plugin referencia os
# reconhecedores de outros alfabetos, mas o app só usa o latino.
# Sem estas linhas o R8 falha com "Missing class ...".
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
