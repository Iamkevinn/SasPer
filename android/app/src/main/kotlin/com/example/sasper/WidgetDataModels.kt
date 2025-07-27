package com.example.sasper

// Representa un único objeto de presupuesto que viene del JSON
data class BudgetWidgetItem(
    val category: String,
    val budgetAmount: Double,
    val spentAmount: Double,
    val progress: Double
)

// Representa un único objeto de transacción que viene del JSON
data class TransactionWidgetItem(
    val description: String?,
    val amount: Double,
    val type: String,
    val category: String?
)