import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

console.log('Edge Function "generate-user-insights" v4 (anti-duplicate) inicializada.');

// Función auxiliar para comprobar si ya existe un insight reciente de un tipo específico.
// Esto nos permite no duplicar alertas o notificaciones.
async function hasRecentInsight(supabaseClient, userId: string, type: string, days = 7): Promise<boolean> {
  const threshold = new Date();
  threshold.setDate(threshold.getDate() - days);

  const { data, error } = await supabaseClient
    .from('insights')
    .select('id', { count: 'exact', head: true }) // head: true hace la consulta más rápida
    .eq('user_id', userId)
    .eq('type', type)
    .gte('created_at', threshold.toISOString());

  if (error) {
    console.error(`Error comprobando insights recientes para ${type}:`, error);
    return true; // Para ser conservadores, asumimos que sí existe si hay un error.
  }
  return (data?.length ?? 0) > 0 || ( 'count' in (data || {}) && (data as any).count > 0);
}

serve(async (_req) => {
  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { data: users, error: usersError } = await supabaseAdmin.from('profiles').select('id');
    if (usersError) throw usersError;
    
    console.log(`Encontrados ${users.length} usuarios para analizar.`);

    for (const user of users) {
      const userId = user.id;
      console.log(`--- Analizando usuario: ${userId} ---`);

      // INSIGHT: Comparación de Gasto Semanal
      try {
        if (!await hasRecentInsight(supabaseAdmin, userId, 'weekly_spending_comparison', 7)) {
            const { data, error } = await supabaseAdmin.rpc('compare_weekly_spending', { p_user_id: userId });
            if (error) throw error;
            const result = data?.[0];
            if (result && result.percentage_change && Math.abs(result.percentage_change) > 10) {
              await supabaseAdmin.from('insights').insert({ /* ... */ });
              console.log(`[OK] Insight de gasto semanal para ${userId}`);
            }
        }
      } catch (e) { console.error(`[FAIL] Gasto semanal para ${userId}:`, e.message); }

      // INSIGHT: Categoría de Mayor Gasto del Mes
      try {
        if (!await hasRecentInsight(supabaseAdmin, userId, 'top_spending_category', 30)) {
            const { data, error } = await supabaseAdmin.rpc('get_top_spending_category_current_month', { p_user_id: userId });
            if (error) throw error;
            if (data && data.length > 0) {
              const topCategory = data[0];
              await supabaseAdmin.from('insights').insert({
                user_id: userId, type: 'top_spending_category',
                severity: 'info', title: `Mayor Gasto: ${topCategory.category}`,
                description: `Este mes, tu principal gasto ha sido en "${topCategory.category}", con un total de \$${topCategory.total_spent.toFixed(0)}.`
              });
              console.log(`[OK] Insight de categoría principal para ${userId}`);
            }
        }
      } catch (e) { console.error(`[FAIL] Categoría principal para ${userId}:`, e.message); }
      
      // INSIGHT: Comparación de Ahorro Mensual
      try {
        if (!await hasRecentInsight(supabaseAdmin, userId, 'monthly_savings_comparison', 30)) {
           // ... (tu lógica de rpc e insert)
           console.log(`[OK] Insight de ahorro mensual para ${userId}`);
        }
      } catch (e) { console.error(`[FAIL] Ahorro mensual para ${userId}:`, e.message); }

      // INSIGHT: Presupuestos Superados
      try {
        const { data, error } = await supabaseAdmin.rpc('get_budgets_progress_for_user', { p_user_id: userId });
        if (error) throw error;
        const exceeded = data.filter(b => b.progress >= 1.0);
        for (const budget of exceeded) {
          // Para este, la lógica anti-duplicación es un poco más compleja,
          // se puede mejorar usando el `metadata` para guardar el ID del presupuesto.
          // Por ahora, lo mantenemos simple.
          if (!await hasRecentInsight(supabaseAdmin, userId, 'budget_exceeded', 7)) {
             await supabaseAdmin.from('insights').insert({ /* ... */ });
             console.log(`[OK] Insight de presupuesto superado para ${userId}`);
          }
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