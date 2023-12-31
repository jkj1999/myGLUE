suppressPackageStartupMessages({
    source(".Rprofile")
    library(dplyr)
    library(ggplot2)
    library(yaml)
})
set.seed(0)


#-------------------------------- Preparations ---------------------------------

display <- read_yaml("config/display.yaml")

ref <- read.csv(snakemake@input[[1]])
min_mean_average_precision <- min(ref$mean_average_precision)
max_mean_average_precision <- max(ref$mean_average_precision)
min_avg_silhouette_width <- min(ref$avg_silhouette_width)
max_avg_silhouette_width <- max(ref$avg_silhouette_width)
min_neighbor_conservation <- min(ref$neighbor_conservation)
max_neighbor_conservation <- max(ref$neighbor_conservation)
min_seurat_alignment_score <- min(ref$seurat_alignment_score)
max_seurat_alignment_score <- max(ref$seurat_alignment_score)
min_avg_silhouette_width_batch <- min(ref$avg_silhouette_width_batch)
max_avg_silhouette_width_batch <- max(ref$avg_silhouette_width_batch)
min_graph_connectivity <- min(ref$graph_connectivity)
max_graph_connectivity <- max(ref$graph_connectivity)

df <- read.csv(snakemake@input[[2]]) %>%
    mutate(
        dataset = factor(dataset, levels = names(display[["dataset"]]), labels = display[["dataset"]]),
        method = factor(method, levels = names(display[["method"]]), labels = display[["method"]]),
        corrupt_rate = factor(corrupt_rate),
        bio = (
            minmax_scale(mean_average_precision, min_mean_average_precision, max_mean_average_precision) +
            minmax_scale(avg_silhouette_width, min_avg_silhouette_width, max_avg_silhouette_width) +
            minmax_scale(neighbor_conservation, min_neighbor_conservation, max_neighbor_conservation)
        ) / 3,
        int = (
            minmax_scale(seurat_alignment_score, min_seurat_alignment_score, max_seurat_alignment_score) +
            minmax_scale(avg_silhouette_width_batch, min_avg_silhouette_width_batch, max_avg_silhouette_width_batch) +
            minmax_scale(graph_connectivity, min_graph_connectivity, max_graph_connectivity)
        ) / 3,
        overall = 0.6 * bio + 0.4 * int
    ) %>%
    as.data.frame()

df_summarise <- df %>%
    group_by(dataset, method) %>%
    summarise(
        dataset = dataset,
        corrupt_rate = corrupt_rate,
        method = method,
        foscttm = foscttm - foscttm[corrupt_rate == 0],
        mean_average_precision = mean_average_precision - mean_average_precision[corrupt_rate == 0],
        seurat_alignment_score = seurat_alignment_score - seurat_alignment_score[corrupt_rate == 0],
        avg_silhouette_width = avg_silhouette_width - avg_silhouette_width[corrupt_rate == 0],
        avg_silhouette_width_batch = avg_silhouette_width_batch - avg_silhouette_width_batch[corrupt_rate == 0],
        neighbor_conservation = neighbor_conservation - neighbor_conservation[corrupt_rate == 0],
        graph_connectivity = graph_connectivity - graph_connectivity[corrupt_rate == 0],
        bio = bio - bio[corrupt_rate == 0],
        int = int - int[corrupt_rate == 0],
        overall = overall - overall[corrupt_rate == 0],
        feature_consistency = feature_consistency
    ) %>%
    group_by(dataset, method, corrupt_rate) %>%
    summarise(
        foscttm_sd = safe_sd(foscttm),
        foscttm = mean(foscttm),
        mean_average_precision_sd = safe_sd(mean_average_precision),
        mean_average_precision = mean(mean_average_precision),
        seurat_alignment_score_sd = safe_sd(seurat_alignment_score),
        seurat_alignment_score = mean(seurat_alignment_score),
        avg_silhouette_width_sd = safe_sd(avg_silhouette_width),
        avg_silhouette_width = mean(avg_silhouette_width),
        avg_silhouette_width_batch_sd = safe_sd(avg_silhouette_width_batch),
        avg_silhouette_width_batch = mean(avg_silhouette_width_batch),
        neighbor_conservation_sd = safe_sd(neighbor_conservation),
        neighbor_conservation = mean(neighbor_conservation),
        graph_connectivity_sd = safe_sd(graph_connectivity),
        graph_connectivity = mean(graph_connectivity),
        bio_sd = safe_sd(bio),
        bio = mean(bio),
        int_sd = safe_sd(int),
        int = mean(int),
        overall_sd = safe_sd(overall),
        overall = mean(overall),
        feature_consistency_sd = safe_sd(feature_consistency),
        feature_consistency = mean(feature_consistency)
    ) %>%
    as.data.frame()

paired_datasets <- names(Filter(function(x) x$paired, snakemake@config[["dataset"]]))
paired_datasets <- Map(function(x) display$dataset[[x]], paired_datasets)


#---------------------------------- Plotting -----------------------------------

gp <- ggplot(data = df_summarise %>% filter(dataset %in% paired_datasets), mapping = aes(
    x = corrupt_rate, y = foscttm,
    ymin = foscttm - foscttm_sd, ymax = foscttm + foscttm_sd,
    group = method, color = method
)) +
    geom_point() + geom_line() + geom_errorbar(width = 0.1) +
    facet_wrap(~ dataset) +
    scale_color_manual(name = "Method", values = unlist(display[["palette"]])) +
    scale_x_discrete(name = "Corruption rate") +
    scale_y_continuous(name = "Increase in FOSCTTM") +
    guides(color = FALSE) +
    ggplot_theme(axis.text.x = element_text(angle = 60, vjust = 0.5))
ggplot_save(snakemake@output[["foscttm"]], gp, width = 5.5, height = 2.5)

gp <- ggplot(data = df_summarise, mapping = aes(
    x = corrupt_rate, y = mean_average_precision,
    ymin = mean_average_precision - mean_average_precision_sd,
    ymax = mean_average_precision + mean_average_precision_sd,
    group = method, color = method
)) +
    geom_point() + geom_line() + geom_errorbar(width = 0.1) +
    facet_wrap(~ dataset) +
    scale_color_manual(name = "Method", values = unlist(display[["palette"]])) +
    scale_x_discrete(name = "Corruption rate") +
    scale_y_continuous(name = "Decrese in mean average precision") +
    guides(color = FALSE) +
    ggplot_theme(axis.text.x = element_text(angle = 60, vjust = 0.5))
ggplot_save(snakemake@output[["map"]], gp, width = 5.5, height = 4)

gp <- ggplot(data = df_summarise, mapping = aes(
    x = corrupt_rate, y = seurat_alignment_score,
    ymin = seurat_alignment_score - seurat_alignment_score_sd,
    ymax = seurat_alignment_score + seurat_alignment_score_sd,
    group = method, color = method
)) +
    geom_point() + geom_line() + geom_errorbar(width = 0.1) +
    facet_wrap(~ dataset) +
    scale_color_manual(name = "Method", values = unlist(display[["palette"]])) +
    scale_x_discrete(name = "Corruption rate") +
    scale_y_continuous(name = "Decrease in Seurat alignment score") +
    guides(color = FALSE) +
    ggplot_theme(axis.text.x = element_text(angle = 60, vjust = 0.5))
ggplot_save(snakemake@output[["sas"]], gp, width = 5.5, height = 4)

gp <- ggplot(data = df_summarise, mapping = aes(
    x = corrupt_rate, y = avg_silhouette_width,
    ymin = avg_silhouette_width - avg_silhouette_width_sd,
    ymax = avg_silhouette_width + avg_silhouette_width_sd,
    group = method, color = method
)) +
    geom_point() + geom_line() + geom_errorbar(width = 0.1) +
    facet_wrap(~ dataset) +
    scale_color_manual(name = "Method", values = unlist(display[["palette"]])) +
    scale_x_discrete(name = "Corruption rate") +
    scale_y_continuous(name = "Decrease in average silhouette width (cell type)") +
    guides(color = FALSE) +
    ggplot_theme(axis.text.x = element_text(angle = 60, vjust = 0.5))
ggplot_save(snakemake@output[["asw"]], gp, width = 5.5, height = 4)

gp <- ggplot(data = df_summarise, mapping = aes(
    x = corrupt_rate, y = avg_silhouette_width_batch,
    ymin = avg_silhouette_width_batch - avg_silhouette_width_batch_sd,
    ymax = avg_silhouette_width_batch + avg_silhouette_width_batch_sd,
    group = method, color = method
)) +
    geom_point() + geom_line() + geom_errorbar(width = 0.1) +
    facet_wrap(~ dataset) +
    scale_color_manual(name = "Method", values = unlist(display[["palette"]])) +
    scale_x_discrete(name = "Corruption rate") +
    scale_y_continuous(name = "Decrease in average silhouette width (omics layer)") +
    guides(color = FALSE) +
    ggplot_theme(axis.text.x = element_text(angle = 60, vjust = 0.5))
ggplot_save(snakemake@output[["aswb"]], gp, width = 5.5, height = 4)

gp <- ggplot(data = df_summarise, mapping = aes(
    x = corrupt_rate, y = neighbor_conservation,
    ymin = neighbor_conservation - neighbor_conservation_sd,
    ymax = neighbor_conservation + neighbor_conservation_sd,
    group = method, color = method
)) +
    geom_point() + geom_line() + geom_errorbar(width = 0.1) +
    facet_wrap(~ dataset) +
    scale_color_manual(name = "Method", values = unlist(display[["palette"]])) +
    scale_x_discrete(name = "Corruption rate") +
    scale_y_continuous(name = "Decrease in neighbor conservation") +
    guides(color = FALSE) +
    ggplot_theme(axis.text.x = element_text(angle = 60, vjust = 0.5))
ggplot_save(snakemake@output[["nc"]], gp, width = 5.5, height = 4)

gp <- ggplot(data = df_summarise, mapping = aes(
    x = corrupt_rate, y = graph_connectivity,
    ymin = graph_connectivity - graph_connectivity_sd,
    ymax = graph_connectivity + graph_connectivity_sd,
    group = method, color = method
)) +
    geom_point() + geom_line() + geom_errorbar(width = 0.1) +
    facet_wrap(~ dataset) +
    scale_color_manual(name = "Method", values = unlist(display[["palette"]])) +
    scale_x_discrete(name = "Corruption rate") +
    scale_y_continuous(name = "Decrease in graph connectivity") +
    guides(color = FALSE) +
    ggplot_theme(axis.text.x = element_text(angle = 60, vjust = 0.5))
ggplot_save(snakemake@output[["gc"]], gp, width = 5.5, height = 4)

gp <- ggplot(data = df_summarise, mapping = aes(
    x = corrupt_rate, y = bio,
    ymin = bio - bio_sd,
    ymax = bio + bio_sd,
    group = method, color = method
)) +
    geom_point() + geom_line() + geom_errorbar(width = 0.1) +
    facet_wrap(~ dataset) +
    scale_color_manual(name = "Method", values = unlist(display[["palette"]])) +
    scale_x_discrete(name = "Corruption rate") +
    scale_y_continuous(name = "Decrease in biology conservation") +
    guides(color = FALSE) +
    ggplot_theme(axis.text.x = element_text(angle = 60, vjust = 0.5))
ggplot_save(snakemake@output[["bio"]], gp, width = 5.5, height = 4)

gp <- ggplot(data = df_summarise, mapping = aes(
    x = corrupt_rate, y = int,
    ymin = int - int_sd,
    ymax = int + int_sd,
    group = method, color = method
)) +
    geom_point() + geom_line() + geom_errorbar(width = 0.1) +
    facet_wrap(~ dataset) +
    scale_color_manual(name = "Method", values = unlist(display[["palette"]])) +
    scale_x_discrete(name = "Corruption rate") +
    scale_y_continuous(name = "Decrease in omics mixing") +
    guides(color = FALSE) +
    ggplot_theme(axis.text.x = element_text(angle = 60, vjust = 0.5))
ggplot_save(snakemake@output[["int"]], gp, width = 5.5, height = 4)

gp <- ggplot(data = df_summarise, mapping = aes(
    x = corrupt_rate, y = overall,
    ymin = overall - overall_sd,
    ymax = overall + overall_sd,
    group = method, color = method
)) +
    geom_point() + geom_line() + geom_errorbar(width = 0.1) +
    facet_wrap(~ dataset) +
    scale_color_manual(name = "Method", values = unlist(display[["palette"]])) +
    scale_x_discrete(name = "Corruption rate") +
    scale_y_continuous(name = "Decrease in overall integration score") +
    guides(color = FALSE) +
    ggplot_theme(axis.text.x = element_text(angle = 60, vjust = 0.5))
ggplot_save(snakemake@output[["overall"]], gp, width = 5.5, height = 4)

gp <- ggplot(data = df_summarise, mapping = aes(
    x = corrupt_rate, y = feature_consistency,
    ymin = feature_consistency - feature_consistency_sd,
    ymax = feature_consistency + feature_consistency_sd,
    group = method, color = method
)) +
    geom_point() + geom_line() + geom_errorbar(width = 0.1) +
    facet_wrap(~ dataset) +
    scale_color_manual(name = "Method", values = unlist(display[["palette"]])) +
    scale_x_discrete(name = "Corruption rate") +
    scale_y_continuous(name = "Feature consistency") +
    guides(color = FALSE) +
    ggplot_theme(axis.text.x = element_text(angle = 60, vjust = 0.5))
ggplot_save(snakemake@output[["fc"]], gp, width = 5.5, height = 4)
