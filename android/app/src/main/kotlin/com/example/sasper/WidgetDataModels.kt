package com.example.sasper

import com.google.gson.annotations.SerializedName

// Representa un único objeto de presupuesto que viene del JSON
data class BudgetWidgetItem(
    // Las claves coinciden con el método toJson() de BudgetProgress en Dart
    @SerializedName("category") val category: String,
    @SerializedName("budgetAmount") val budgetAmount: Double,
    @SerializedName("spentAmount") val spentAmount: Double,
    @SerializedName("progress") val progress: Double // 'progress' es un decimal (0.0 a 1.0)
)

// Representa un único objeto de transacción que viene del JSON
data class TransactionWidgetItem(
    // Las claves coinciden con el método toJson() de TransactionModel en Dart
    @SerializedName("description") val description: String?,
    @SerializedName("amount") val amount: Double,
    @SerializedName("category") val category: String?
    // No necesitamos "type" aquí si no lo vamos a usar en el layout del widget.
)