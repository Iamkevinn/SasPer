// android/app/src/main/kotlin/com/example/sasper/GoalsWidgetService.kt
package com.example.sasper

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale

// El servicio que retorna la factory
class GoalsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return GoalsListFactory(this.applicationContext)
    }
}

// La factory que gestiona los datos de la lista
class GoalsListFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var goals: List<JSONObject> = emptyList()

    override fun onCreate() {
        // Se llama al crear la factory.
    }

    override fun onDataSetChanged() {
        // Aquí es donde obtenemos los datos.
        // Usaremos SharedPreferences, que es donde home_widget guarda los datos.
        val widgetData = HomeWidgetPlugin.getData(context)
        val goalsJsonString = widgetData.getString("goals_list", "[]")
        val jsonArray = JSONArray(goalsJsonString)
        goals = List(jsonArray.length()) { i -> jsonArray.getJSONObject(i) }
    }

    override fun onDestroy() {
        goals = emptyList()
    }

    override fun getCount(): Int = goals.size

    override fun getViewAt(position: Int): RemoteViews {
        val goal = goals[position]
        val views = RemoteViews(context.packageName, R.layout.widget_goal_item_layout)

        val name = goal.optString("name", "Sin Nombre")
        val currentAmount = goal.optDouble("current_amount", 0.0)
        val targetAmount = goal.optDouble("target_amount", 0.0)

        val progress = if (targetAmount > 0) ((currentAmount / targetAmount) * 100).toInt() else 0
        
        val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "CO"))
        val progressText = "${currencyFormat.format(currentAmount)} / ${currencyFormat.format(targetAmount)}"
        
        views.setTextViewText(R.id.goal_name, name)
        views.setProgressBar(R.id.goal_progress_bar, 100, progress, false)
        views.setTextViewText(R.id.goal_progress_text, progressText)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}