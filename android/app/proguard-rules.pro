# —— 为将来开启混淆准备的保留规则 ——
# 注解与反射信息
-keepattributes *Annotation*,InnerClasses,Signature,EnclosingMethod

# Tink（Ed25519/X25519）
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# Nimbus JOSE JWT
-keep class com.nimbusds.** { *; }
-dontwarn com.nimbusds.**

# BouncyCastle
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**
-keep class ** extends java.security.Provider { *; }

# MSAL/Identity
-keep class com.microsoft.identity.** { *; }
-dontwarn com.microsoft.identity.**

# 常见注解包
-keep class javax.annotation.** { *; }
-dontwarn javax.annotation.**
-keep @interface edu.umd.cs.findbugs.annotations.SuppressFBWarnings
-dontwarn edu.umd.cs.findbugs.annotations.**
