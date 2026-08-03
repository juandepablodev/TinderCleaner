# Misión del Proyecto

## Qué construimos
Una herramienta de productividad para iOS que permite limpiar el almacenamiento
del iPhone de forma extremadamente ágil: revisar la galería completa en
minutos, no en horas.

## Para quién
Usuarios con la galería saturada (miles de fotos y vídeos acumulados) que posponen la
limpieza porque el flujo nativo de gestión de la galería es lento y tedioso para decisiones
masivas.

## Cómo funciona
La interfaz se basa en tarjetas deslizables (swipe estilo Tinder):
- Un gesto (derecha) CONSERVA la foto/vídeo.
- El gesto opuesto (izquierda) la marca para ELIMINAR.
- La eliminación es una acción en dos pasos: primero se marca, y al final de
  la sesión el usuario confirma el borrado por lotes, que PhotoKit envía a la
  papelera nativa del sistema (Álbum "Eliminados recientemente", recuperable
  30 días). NUNCA se borra nada de forma irreversible desde la app.

## Valor central: PRIVACIDAD
Ninguna imagen, vídeo, metadato, estadística o telemetría saldrá jamás del
dispositivo. La app es 100% local, funciona en Modo Avión y no contiene
ninguna dependencia con acceso a red. Este principio es irrenunciable: si
una feature futura lo requiriese, la feature se rechaza.

## Definición de éxito
- Revisar 100 fotos y vídeos en menos de 5 minutos.
- Cero datos enviados fuera del dispositivo (verificable por inspección de
  tráfico en Modo Avión).
- Cero borrados accidentales irreversibles (siempre pasa por papelera nativa
  + confirmación explícita del usuario).