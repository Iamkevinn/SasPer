import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

console.log('Edge Function "generate-user-insights" v3 (multi-insight) inicializada.');

// La función principal se ejecuta cada vez que se invoca el endpoint.
serve(async (_req) => {
  try {
    // Es CRÍTICO usar el rol de servicio (SERVICE_ROLE_KEY) para poder operar
    // sobre los datos de todos los usuarios.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. Obtener la lista de todos los IDs de usuario.
    const { data: users, error: usersError } = await supabaseAdmin.from('profiles').select('id');
    if (usersError) throw usersError;
    
    console.log(`Encontrados ${users.length} usuarios para analizar.`);

    // 2. Iterar sobre cada usuario para generar sus insights.
    for (const user of users) {
      const userId = user.id;
      console.log(`--- Analizando usuario: ${userId} ---`);

      // INSIGHT: Comparación de Gasto Semanal
      try {
        const { data, error } = await supabaseAdmin.rpc('compare_weekly_spending', { p_user_id: userId });
        if (error) throw error;
        const result = data?.[0];
        if (result && result.percentage_change && Math.abs(result.percentage_change) > 10) {
          const isIncrease = result.percentage_change > 0;
          await supabaseAdmin.from('insights').insert({
            user_id: userId, type: 'weekly_spending_comparison',
            severity: isIncrease ? 'warning' : 'success',
            title: `${isIncrease ? '+' : ''}${result.percentage_change.toFixed(0)}% en Gastos`,
            description: `Esta semana gastaste \$${result.current_week_total.toFixed(0)}, un cambio del ${result.percentage_change.toFixed(0)}% respecto a los \$${result.previous_week_total.toFixed(0)} de la semana anterior.`
          });
          console.log(`[OK] Insight de gasto semanal para ${userId}`);
        }
      } catch (e) { console.error(`[FAIL] Gasto semanal para ${userId}:`, e.message); }

      // INSIGHT: Categoría de Mayor Gasto del Mes
      try {
        const { data, error } = await supabaseAdmin.rpc('get_top_spending_category_current_month', { p_user_id: userId });
        if (error) throw error;
        if (data && data.length > 0) {
          const topCategory = data[0];
          await supabaseAdmin.from('insights').insert({
            user_id: userId, type: 'top_spending_category',
            severity: 'info',
            title: `Mayor Gasto: ${topCategory.category}`,
            description: `Este mes, tu principal gasto ha sido en "${topCategory.category}", con un total de \$${topCategory.total_spent.toFixed(0)}.`
          });
          console.log(`[OK] Insight de categoría principal para ${userId}`);
        }
      } catch (e) { console.error(`[FAIL] Categoría principal para ${userId}:`, e.message); }

      // INSIGHT: Comparación de Ahorro Mensual
      try {
        const { data, error } = await supabaseAdmin.rpc('compare_monthly_savings', { p_user_id: userId });
        if (error) throw error;
        const result = data?.[0];
        if (result && result.previous_month_savings !== 0) {
          const diff = result.current_month_savings - result.previous_month_savings;
          if (Math.abs(diff) > 1) {
            const isIncrease = diff > 0;
            await supabaseAdmin.from('insights').insert({
              user_id: userId, type: 'monthly_savings_comparison',
              severity: isIncrease ? 'success' : 'warning',
              title: isIncrease ? `Mejora en Ahorros` : `Reducción en Ahorros`,
              description: `Este mes, tu ahorro neto fue de \$${result.current_month_savings.toFixed(0)}, en comparación con los \$${result.previous_month_savings.toFixed(0)} del mes anterior.`,
            });
            console.log(`[OK] Insight de ahorro mensual para ${userId}`);
          }
        }
      } catch (e) { console.error(`[FAIL] Ahorro mensual para ${userId}:`, e.message); }

      // INSIGHT: Presupuestos Superados
      try {
        const { data, error } = await supabaseAdmin.rpc('get_budgets_progress_for_user', { p_user_id: userId });
        if (error) throw error;
        const exceeded = data.filter(b => b.progress >= 1.0);
        for (const budget of exceeded) {
          await supabaseAdmin.from('insights').insert({
            user_id: userId, type: 'budget_exceeded',
            severity: 'alert',
            title: `Presupuesto de "${budget.category}" superado`,
            description: `Has gastado \$${budget.spent_amount.toFixed(0)} de tu presupuesto de \$${budget.budget_amount.toFixed(0)}.`,
          });
          console.log(`[OK] Insight de presupuesto superado para ${userId}`);
        }
      } catch (e) { console.error(`[FAIL] Presupuestos para ${userId}:`, e.message); }

      // INSIGHT: Pagos Recurrentes Próximos (en los próximos 3 días)
      try {
        const { data, error } = await supabaseAdmin.rpc('get_upcoming_recurring_payments', { p_user_id: userId, days_ahead: 3 });
        if (error) throw error;
        for (const payment of data) {
          const dueDate = new Date(payment.next_due_date);
          const formattedDate = `${dueDate.getDate()}/${dueDate.getMonth() + 1}`; // Formato D/M
          await supabaseAdmin.from('insights').insert({
            user_id: userId, type: 'upcoming_payment',
            severity: 'info',
            title: `Próximo pago: ${payment.description}`,
            description: `Tu pago recurrente de \$${Math.abs(payment.amount).toFixed(0)} vence el ${formattedDate}.`,
          });
          console.log(`[OK] Insight de pago recurrente para ${userId}`);
        }
      } catch (e) { console.error(`[FAIL] Pagos recurrentes para ${userId}:`, e.message); }

      // INSIGHT: Alerta de Saldo Bajo (por debajo de $50)
      try {
        const { data, error } = await supabaseAdmin.rpc('check_low_balance_accounts', { p_user_id: userId, threshold: 50 });
        if (error) throw error;
        for (const account of data) {
          await supabaseAdmin.from('insights').insert({
            user_id: userId, type: 'low_balance_warning',
            severity: 'warning',
            title: `Saldo bajo en "${account.account_name}"`,
            description: `El saldo actual de tu cuenta es de \$${account.current_balance.toFixed(0)}.`,
          });
          console.log(`[OK] Insight de saldo bajo para ${userId}`);
        }
      } catch (e) { console.error(`[FAIL] Saldo bajo para ${userId}:`, e.message); }
      
      // INSIGHT: Hitos de Metas Alcanzados (25%, 50%, 75%, 90%)
      try {
        const { data, error } = await supabaseAdmin.rpc('check_goal_milestones', { p_user_id: userId });
        if (error) throw error;
        for (const goal of data) {
           await supabaseAdmin.from('insights').insert({
              user_id: userId, type: 'goal_milestone',
              severity: 'success',
              title: `¡Meta a la vista!`,
              description: `¡Felicidades! Has superado el ${goal.milestone}% de tu meta "${goal.goal_name}".`,
              metadata: { goal_name: goal.goal_name, milestone: goal.milestone }
            });
           console.log(`[OK] Insight de hito de meta para ${userId}`);
        }
      } catch(e) { console.error(`[FAIL] Hitos de metas para ${userId}:`, e.message); }

      console.log(`--- Análisis para ${userId} completado ---`);
    } // Fin del bucle de usuarios

    return new Response(
      JSON.stringify({ message: `Análisis de insights completado para ${users.length} usuarios.` }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error) {
    console.error('Error fatal en la Edge Function:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});