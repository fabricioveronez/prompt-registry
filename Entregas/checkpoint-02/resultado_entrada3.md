ALERTA: Forge - lag do consumer em 9min e subindo, batch forge-batch-ingest
IMPACTO: pipeline downstream Sentinel começando a atrasar
HIPÓTESE INICIAL: batch atrasado após falha do job anterior
AÇÃO IMEDIATA: reiniciar/reprocessar o batch forge-batch-ingest e monitorar recuperação do lag
ESCALAR PARA: @data-platform se lag não estabilizar em 15min