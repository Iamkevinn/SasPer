// Archivo: android/app/src/main/kotlin/com/example/sasper/GoalsWidgetService.kt
package com.example.sasper

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.text.NumberFormat
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.Locale

class GoalsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return GoalsListFactory(this.applicationContext)
    }
}

class GoalsListFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var goals: List<Goal> = emptyList()
    private val currencyFormat: NumberFormat = NumberFormat.getCurrencyInstance(Locale("es", "CO")).apply {
        maximumFractionDigits = 0
    }

    data class Goal(
        val id: String,
        val name: String,
        val current_amount: Double,
        val target_amount: Double,
        val deadline: String?,
        val icon_type: String?
    ) {
        val progress: Int
            get() = if (target_amount > 0) ((current_amount / target_amount) * 100).toInt().coerceIn(0, 100) else 0
    }

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs: SharedPreferences = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonString = prefs.getString("goals_list", null)

        goals = if (jsonString != null) {
            try {
                val type = object : TypeToken<List<Goal>>() {}.type
                Gson().fromJson(jsonString, type)
            } catch (e: Exception) {
                e.printStackTrace()
                emptyList()
            }
        } else {
            emptyList()
        }
    }

    override fun getViewAt(position: Int): RemoteViews {
        val goal = goals[position]
        val views = RemoteViews(context.packageName, R.layout.widget_goal_item_layout)

        views.setTextViewText(R.id.goal_name, goal.name)
        views.setTextViewText(R.id.goal_percentage, "${goal.progress}%")
        // --- [CORRECCIÓN] Se reemplazó "/" por "." ---
        views.setProgressBar(R.id.goal_progress_bar, 100, goal.progress, false)
        views.setTextViewText(R.id.goal_current_amount, currencyFormat.format(goal.current_amount))
        // --- [CORRECCIÓN] Se reemplazó "/" por "." ---
        views.setTextViewText(R.id.goal_target_amount, "de ${currencyFormat.format(goal.target_amount)}")

        if (!goal.deadline.isNullOrEmpty()) {
            try {
                val dueDate = ZonedDateTime.parse(goal.deadline)
                val formatter = DateTimeFormatter.ofPattern("MMM yyyy", Locale("es", "ES"))
                views.setTextViewText(R.id.goal_status_text, "Meta para ${formatter.format(dueDate)}")
            } catch (e: DateTimeParseException) {
                views.setTextViewText(R.id.goal_status_text, "")
            }
        } else {
            views.setTextViewText(R.id.goal_status_text, "Sin fecha límite")
        }

        val fillInIntent = Intent().apply {
            val extras = Bundle()
            extras.putString("goal_id", goal.id)
            putExtras(extras)
        }
        views.setOnClickFillInIntent(R.id.goal_item_container, fillInIntent)

        return views
    }

    override fun getCount(): Int = goals.size
    override fun getItemId(position: Int): Long {
        return goals.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()
    }
    override fun hasStableIds(): Boolean = true
    override fun onDestroy() {}
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
}