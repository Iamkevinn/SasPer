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

// --- [NUEVO Y CRUCIAL] CLASE PARA EL WIDGET DE PRÓXIMO PAGO ---
// Esta es la clase que faltaba. Sus campos deben coincidir con las claves
// del JSON que se genera en el método `toJson()` de `UpcomingPayment` en Dart.
data class UpcomingPayment(
    @SerializedName("id") val id: String,
    @SerializedName("concept") val concept: String,
    @SerializedName("amount") val amount: Double,
    @SerializedName("nextDueDate") val nextDueDate: String, // Formato ISO 8601: "2025-11-20T10:00:00.000"
    @SerializedName("type") val type: String // "debt" o "recurring"
)
// --- [NUEVO] CLASES PARA WIDGET GRANDE ---
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
