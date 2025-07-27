package com.example.sasper

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale

class WidgetListFactory(private val context: Context, private val intent: Intent) : RemoteViewsService.RemoteViewsFactory {
    private var items: List<Any> = emptyList()
    private val listType = intent.getStringExtra("LIST_TYPE") ?: ""

    override fun onCreate() {
        // No es necesario hacer nada aquí.
    }

    override fun onDataSetChanged() {
        // Este método se llama cuando notificamos un cambio. Aquí cargamos los datos.
        val widgetData = HomeWidgetPlugin.getData(context)
        val gson = Gson()
        
        if (listType == "BUDGETS") {
            val budgetsJson = widgetData.getString("featured_budgets_json", "[]")
            val budgetListType = object : TypeToken<List<BudgetWidgetItem>>() {}.type
            items = gson.fromJson(budgetsJson, budgetListType)
        } else if (listType == "TRANSACTIONS") {
            val transactionsJson = widgetData.getString("recent_transactions_json", "[]")
            val transactionListType = object : TypeToken<List<TransactionWidgetItem>>() {}.type
            items = gson.fromJson(transactionsJson, transactionListType)
        }
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position >= items.size) return null

        // Dependiendo del tipo de lista, usamos un layout u otro y rellenamos los datos.
        return if (listType == "BUDGETS") {
            val budget = items[position] as BudgetWidgetItem
            RemoteViews(context.packageName, R.layout.widget_budget_item_layout).apply {
                setTextViewText(R.id.widget_item_budget_title, "🍔 ${budget.category}")
                setProgressBar(R.id.widget_item_budget_progress, 100, (budget.progress * 100).toInt(), false)
            }
        } else { // TRANSACTIONS
            val tx = items[position] as TransactionWidgetItem
            RemoteViews(context.packageName, R.layout.widget_transaction_item_layout).apply {
                setTextViewText(R.id.widget_item_transaction_title, tx.description ?: "Transacción")
                val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "ES"))
                setTextViewText(R.id.widget_item_transaction_amount, currencyFormat.format(tx.amount))
                setTextColor(R.id.widget_item_transaction_amount, if (tx.amount < 0) Color.parseColor("#E53935") else Color.parseColor("#43A047"))
            }
        }
    }

    // El resto de los métodos pueden quedar con las implementaciones por defecto, que son seguras.
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}