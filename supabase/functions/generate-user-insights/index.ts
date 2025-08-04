// Importa los módulos necesarios de Deno y Supabase.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

console.log('Edge Function "generate-user-insights" inicializada.');

// La función principal se ejecuta cada vez que se invoca el endpoint.
serve(async (_req) => {
  try {
    // Es CRÍTICO usar el rol de servicio (SERVICE_ROLE_KEY) para poder operar
    // sobre los datos de todos los usuarios. Esta clave debe estar configurada
    // como un secreto en tu proyecto de Supabase.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. Obtener la lista de todos los IDs de usuario de la tabla de perfiles.
    const { data: users, error: usersError } = await supabaseAdmin
      .from('profiles')
      .select('id');

    if (usersError) {
      console.error('Error al obtener la lista de usuarios:', usersError);
      throw usersError;
    }
    
    console.log(`Encontrados ${users.length} usuarios para analizar.`);

    // 2. Iterar sobre cada usuario para generar sus insights personalizados.
    for (const user of users) {
      const userId = user.id;
      console.log(`--- Analizando usuario: ${userId} ---`);

      // --- Insight #1: Comparación de Gasto Semanal ---
      try {
        const { data: weeklyData, error: rpcError } = await supabaseAdmin.rpc(
          'compare_weekly_spending', 
          { p_user_id: userId }
        );

        if (rpcError) throw rpcError;
        
        const result = weeklyData?.[0];
        // Solo creamos el insight si hay un cambio porcentual significativo (mayor al 10%).
        if (result && result.percentage_change && Math.abs(result.percentage_change) > 10) {
          
          const isIncrease = result.percentage_change > 0;
          const formattedChange = `${isIncrease ? '+' : ''}${result.percentage_change.toFixed(0)}%`;
          const title = `${formattedChange} en Gastos`;
          const description = `Esta semana gastaste \$${result.current_week_total.toFixed(0)}, un cambio del ${formattedChange} respecto a los \$${result.previous_week_total.toFixed(0)} de la semana anterior.`;

          // Guardamos el insight en la base de datos.
          await supabaseAdmin.from('insights').insert({
            user_id: userId,
            type: 'weekly_spending_comparison',
            severity: isIncrease ? 'warning' : 'success', // 'warning' si gastas más, 'success' si gastas menos.
            title: title,
            description: description,
            metadata: { 
              current: result.current_week_total, 
              previous: result.previous_week_total 
            }
          });
          console.log(`[OK] Insight de gasto semanal guardado para el usuario ${userId}`);
        } else {
           console.log(`[INFO] Sin cambio de gasto semanal significativo para el usuario ${userId}.`);
        }
      } catch (error) {
        console.error(`[FAIL] Error generando insight de gasto semanal para ${userId}:`, error.message);
      }

      // --- Insight #2: Categoría de Mayor Gasto del Mes ---
      try {
        const { data: topCategoryData, error: topCategoryError } = await supabaseAdmin.rpc(
          'get_top_spending_category_current_month',
          { p_user_id: userId }
        );

        if (topCategoryError) throw topCategoryError;
        
        if (topCategoryData && topCategoryData.length > 0) {
          const topCategory = topCategoryData[0];
          
          const title = `Mayor Gasto: ${topCategory.category}`;
          const description = `Este mes, tu principal gasto ha sido en "${topCategory.category}", con un total de \$${topCategory.total_spent.toFixed(0)}.`;

          // Guardamos el nuevo insight en la base de datos.
          await supabaseAdmin.from('insights').insert({
            user_id: userId,
            type: 'top_spending_category',
            severity: 'info', // Este tipo de insight es meramente informativo.
            title: title,
            description: description,
            metadata: { 
              category: topCategory.category,
              total: topCategory.total_spent 
            }
          });
          console.log(`[OK] Insight de categoría principal guardado para el usuario ${userId}`);
        } else {
          console.log(`[INFO] Sin datos de categoría principal para el usuario ${userId}.`);
        }
      } catch (error) {
        console.error(`[FAIL] Error generando insight de categoría principal para ${userId}:`, error.message);
      }
      
      console.log(`--- Análisis para ${userId} completado ---`);

    } // Fin del bucle de usuarios

    // 3. Devolver una respuesta exitosa.
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