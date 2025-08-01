package com.example.sasper

import com.google.gson.annotations.SerializedName

// Representa un único objeto de presupuesto que viene del JSON
data class BudgetWidgetItem(
    // Mapea la clave "category" del JSON a esta propiedad
    @SerializedName("category") val category: String,

    @SerializedName("budgetAmount") val budgetAmount: Double,
    @SerializedName("spentAmount") val spentAmount: Double,
    @SerializedName("progress") val progress: Double
)

// Representa un único objeto de transacción que viene del JSON
data class TransactionWidgetItem(
    @SerializedName("description") val description: String?,
    @SerializedName("amount") val amount: Double,
    @SerializedName("type") val type: String,
    @SerializedName("category") val category: String?
)