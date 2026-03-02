// Archivo: android/app/src/main/kotlin/com/example/sasper/WidgetDataModels.kt

package com.example.sasper

import com.google.gson.annotations.SerializedName

// --- CLASES PARA WIDGETS DEL DASHBOARD (Mediano y Grande) ---

data class BudgetWidgetItem(
    @SerializedName("category") val category: String,
    @SerializedName("budgetAmount") val budgetAmount: Double,
    @SerializedName("spentAmount") val spentAmount: Double,
    @SerializedName("progress") val progress: Double
)

data class TransactionWidgetItem(
    @SerializedName("description") val description: String?,
    @SerializedName("amount") val amount: Double,
    @SerializedName("category") val category: String?
)

// --- CLASE PARA EL WIDGET DE PRÓXIMO PAGO ---
// Los campos coinciden exactamente con las claves del toJson() de Dart.
//
// Campos nuevos respecto a la versión anterior:
//   · subtype: texto en español listo para mostrar en pantalla.
//              Ejemplos: "Prueba gratuita", "Cuota 3 de 12"
//              Puede ser null para deudas y recurrentes.
//
// El campo [type] sigue siendo el identificador técnico del enum Dart:
//   "debt" | "recurring" | "freeTrial" | "creditCard"
data class UpcomingPayment(
    @SerializedName("id")          val id: String,
    @SerializedName("concept")     val concept: String,
    @SerializedName("amount")      val amount: Double,
    @SerializedName("nextDueDate") val nextDueDate: String,  // ISO 8601
    @SerializedName("type")        val type: String,
    // Nullable — Gson lo dejará null si no viene en el JSON (compatibilidad hacia atrás)
    @SerializedName("subtype")     val subtype: String? = null,
    @SerializedName("iconName")    val iconName: String? = null
)

// --- CLASES PARA WIDGET GRANDE ---
data class WidgetBudget(
    @SerializedName("category_name") val category: String,
    val progress: Double
)

data class WidgetTransaction(
    val description: String?,
    val category: String?,
    val amount: Double,
    val type: String
)