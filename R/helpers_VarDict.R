#'A script, written in R, where all the appropriate functions for 
#'the analysis of VarDict are located.
#'
#'Authors: Nikos Pechlivanis(github:npechl), Stella Fragkouli(github:sfragkoul)
#'
#'

#TP SNVS-----------------------------------------------------------------------
read_vcf_VarDict <- function(path, gt, merged_file) {
  #takes two files and produce a caller vcf file in a certain format 
  vcf <- read.vcfR(paste0(path, "/", merged_file, "_VarDict_norm.vcf"), verbose = FALSE )
  
  vcf_df = vcf |>
    merge_VarDict(gt) |>
    clean_VarDict()
  
  return(vcf_df)
  
}


plot_snvs_TP_VarDict <- function(df, vcf_GT, vcf_caller, merged_file){
    #plotting function
    out1 = bar_plots_VarDict(df)
    out2 = density_plot_VarDict(df)
    out3 = bubble_plots_VarDict(df)
    out4 = venn_plot_VarDict(vcf_GT, vcf_caller)
    
    multi2 = out2$groundtruth / out2$VarDict &
        
        theme(
            plot.margin = margin(10, 10, 10, 10)
        )

    ann1 = (out1$coverage + theme(plot.margin = margin(r = 50))) + 
        (out1$allele + theme(plot.margin = margin(r = 50))) + 
        multi2 +
        
        plot_layout(
            widths = c(1, 1, 3)
        )
    
    ann2 = out3 + out4 +
        
        plot_layout(
            widths = c(2, 1)
        )

    multi = ann1 / ann2 +
        
        plot_layout(heights = c(1.5, 1)) + 
        plot_annotation(title = merged_file)
    
    
    return(list(multi, out4))
}

merge_VarDict <- function(VarDict_somatic_vcf, merged_gt) {
    #return cleaned vcf
    VarDict_s0  = VarDict_somatic_vcf |> vcfR::getFIX() |> as.data.frame() |> setDT()
    VarDict_s1  = VarDict_somatic_vcf |> extract_gt_tidy() |> setDT()
    VarDictgatk_s21 = VarDict_somatic_vcf |> extract_info_tidy() |> setDT()
    
    VarDict_somatic = cbind(VarDict_s0[VarDict_s1$Key, ], VarDict_s1)
    
    
    #Merge everything into a common file
    merged_gt$POS = as.character(merged_gt$POS)
    
    merged_bnch = merge(merged_gt, VarDict_somatic,  by = "POS", all.x = TRUE)
    
    merged_bnch$POS = as.numeric(merged_bnch$POS)
    
    merged_bnch = merged_bnch[order(POS)]
    
    colnames(merged_bnch) = c(
        "POS",	"Ground Truth REF",	"Ground Truth DP",
        "Ground Truth ALT", "Ground Truth AD", 
        "Ground Truth AF", "CHROM", "ID", "VarDict REF",	
        "VarDict ALT", "VarDict QUAL",	"VarDict FILTER",
        "key", "Indiv", "gt_GT", "VarDict DP", "gt_VD", "VarDict AD", 
        "VarDict AF", "gt_RD", "gt_ALD", "gt_GT_alleles"
    )
    
    return(merged_bnch)
    
}


clean_VarDict <- function(df) {
    #function to produce the caller's reported variants in the desired format 
    df2 = df[, c(
        "POS",
        
        "Ground Truth REF",
        "Ground Truth ALT",
        "Ground Truth DP",
        "Ground Truth AF",
        
        "VarDict REF", 
        "VarDict ALT", 
        "VarDict DP",
        "VarDict AF"
    ), with = FALSE]
    
    
    
    df2 = df2[, by = c(
        "POS",
        "Ground Truth REF",
        "Ground Truth DP",
        "VarDict REF", 
        "VarDict ALT", 
        "VarDict DP",
        "VarDict AF"
        
    ), .(
        "Ground Truth ALT" = `Ground Truth ALT` |> tstrsplit(",") |> unlist(),
        "Ground Truth AF"  = `Ground Truth AF` |> tstrsplit(",") |> unlist()
    )]



    VarDict_alt = str_split(df2$`VarDict ALT`, ",")
    VarDict_af = str_split(df2$`VarDict AF`, ",")


    cln = mapply(
        function(x, y, z) {

            index = which(y == x)

            return(
                c(y[index], z[index])
            )

        },

        df2$`Ground Truth ALT`, VarDict_alt, VarDict_af
    )


    df2$`VarDict ALT` = cln |> lapply(function(x) { return(x [1]) }) |> unlist()
    df2$`VarDict AF`  = cln |> lapply(function(x) { return(x [2]) }) |> unlist()
    
    df2[which(is.na(`VarDict AF`))]$`VarDict DP` = NA
    df2[which(is.na(`VarDict AF`))]$`VarDict REF` = NA
    
    df2 = df2[, c(
        "POS", 
        "Ground Truth REF",
        "Ground Truth ALT",
        "Ground Truth DP",
        "Ground Truth AF",
        "VarDict REF", 
        "VarDict ALT", 
        "VarDict DP",
        "VarDict AF"
    ), with = FALSE]

    return(df2)
    
}


bar_plots_VarDict <- function(q) {
    #function to produce variants' barplots for coverage and AF
    q[which(q$`VarDict ALT` == "")]$`VarDict ALT` = NA
    
    #DP plot
    df = q[, c(
        "POS", 
        "Ground Truth DP",
        "VarDict DP"
    ), with = FALSE] |>
        unique() |>
        
        melt(id.vars = "POS", variable.factor = FALSE, value.factor = FALSE)
    
    o1 = ggplot(data = df) +
        
        geom_point(aes(x = variable, y = value, fill = variable),
                   position = position_jitternormal(sd_x = .01, sd_y = 0),
                   shape = 21, stroke = .1, size = 2.5) +
        
        geom_boxplot(aes(x = variable, y = value, fill = variable),
                     width = .25, alpha = .5, outlier.shape = NA) +
        
        scale_fill_manual(
            values = c(
                "Ground Truth DP" = "#43ae8d",
                "VarDict DP"      = "#8d43ae"
            )
        ) +
        
        scale_x_discrete(
            breaks = c("Ground Truth DP", "VarDict DP"),
            labels = c("Ground Truth", "VarDict")
        ) +
        
        scale_y_continuous(labels = scales::comma) +
        
        theme_minimal() +
        
        theme(
            legend.position = "none",
            
            axis.title.x = element_blank(),
            axis.title.y = element_text(face = "bold", size = 13),
            axis.text.x = element_text(face = "bold", size = 13),
            axis.text.y = element_text(face = "bold", size = 13),
            
            axis.line = element_line(),
            axis.ticks = element_line(),
            
            panel.grid = element_blank(),
            
            plot.margin = margin(20, 20, 20, 20)
        ) +
        
        labs(
            y = "Coverage (No. of reads)"
        )
    
    
    #AF plot
    df = q[, c(
        "POS",
        "Ground Truth AF",
        "VarDict AF"
    ), with = FALSE] |>
        unique() |>
        
        melt(id.vars = "POS", variable.factor = FALSE, value.factor = FALSE)
    
    o2 = ggplot(data = df[which(!is.na(value) & value != 0)]) +
        
        geom_point(aes(x = variable, y = value, fill = variable),
                   position = position_jitternormal(sd_x = .01, sd_y = 0),
                   shape = 21, stroke = .1, size = 2.5) +
        
        geom_boxplot(aes(x = variable, y = value, fill = variable),
                     width = .25, alpha = .5, outlier.shape = NA) +
        
        scale_fill_manual(
            values = c(
                "Ground Truth AF" = "#43ae8d",
                "VarDict AF"      = "#8d43ae"
            )
        ) +
        
        scale_x_discrete(
            breaks = c("Ground Truth AF", "VarDict AF"),
            labels = c("Ground Truth", "VarDict")
        ) +
        
        scale_y_continuous(labels = scales::percent, trans = "log10") +
        
        theme_minimal() +
        
        theme(
            legend.position = "none",
            
            axis.title.x = element_blank(),
            axis.title.y = element_text(face = "bold", size = 13),
            axis.text.x = element_text(face = "bold", size = 13),
            axis.text.y = element_text(face = "bold", size = 13),
            
            axis.line = element_line(),
            axis.ticks = element_line(),
            
            panel.grid = element_blank(),
            
            plot.margin = margin(20, 20, 20, 20)
        ) +
        
        labs(
            y = "Allele Frequency"
        )

    
    return(
        list(
            "coverage" = o1,
            "allele" = o2
        )
    )
    
}


density_plot_VarDict <- function(q) {
    #function to produce AF density plots
    q[which(q$`VarDict ALT` == "")]$`VarDict ALT` = NA
    
    df = q[, c(
        "POS", 
        "Ground Truth AF",
        "Ground Truth ALT",
        "VarDict ALT",
        "VarDict AF"
    ), with = FALSE] |>
        unique()
    
    #Ground Truth AF density plot
    
    o1 = ggplot(data = df[, 1:3], aes(x = `Ground Truth AF`)) +
        
        geom_density(aes(color = `Ground Truth ALT`, fill = `Ground Truth ALT`),
                     alpha = .5) +
        
        scale_x_continuous(expand = c(0, 0), breaks = c(.25, .5, .75, 1), limits = c(0, 1), labels = scales::percent) +
        scale_y_continuous(expand = c(0, 0), limits = c(0, 15), breaks = c(5, 10, 15)) +
        
        scale_fill_npg() +
        scale_color_npg() +
        
        facet_wrap(vars(`Ground Truth ALT`), nrow = 1) +
        
        theme_minimal() +
        
        theme(
            legend.position = "none",
            
            axis.title.x = element_blank(),
            axis.title.y = element_text(face = "bold", size = 13),
            strip.text = element_text(face = "bold", size = 13),
            axis.text.y = element_text(face = "bold", size = 13),
            axis.text.x = element_blank(),
            
            panel.spacing = unit(1, "lines"),
            
            panel.grid = element_line(linetype = "dashed")
        ) +
        
        labs(y = "Ground Truth (density)")
    
    #Caller AF density plot
    
    o2 = ggplot(data = df[which(!is.na(`VarDict ALT`)), c(1, 4, 5)], aes(x = `VarDict AF`)) +
        
        geom_density(aes(color = `VarDict ALT`, fill = `VarDict ALT`),
                     alpha = .5) +
        
        scale_x_continuous(expand = c(0, 0), breaks = c(.25, .5, .75, 1), limits = c(0, 1), labels = scales::percent) +
        scale_y_continuous(expand = c(0, 0), limits = c(0, 15), breaks = c(5, 10, 15))+
        
        scale_fill_npg() +
        scale_color_npg() +
        
        facet_wrap(vars(`VarDict ALT`), nrow = 1) +
        
        theme_minimal() +
        
        theme(
            legend.position = "none",
            axis.title.x = element_text(face = "bold", size = 13),
            axis.title.y = element_text(face = "bold", size = 13),
            strip.text = element_blank(), # element_text(face = "bold", size = 13),
            axis.text.y = element_text(face = "bold", size = 13),
            axis.text.x = element_text(face = "bold", size = 11),
            
            panel.spacing = unit(1, "lines"),
            
            panel.grid = element_line(linetype = "dashed")
        ) +
        
        labs(
            x = "Allele Frequency",
            y = "VarDict (density)"
        )
    
    return(
        list(
            "groundtruth" = o1,
            "VarDict" = o2
        )
    )
    
}


bubble_plots_VarDict <- function(q) {
    #function to produce SNVs bubble plot
    # q[which(q$`VarDict ALT` == "")]$`VarDict ALT` = NA
    
    
    q1 = q[which(q$`VarDict ALT` != "")]
    
    
    o = ggplot() +
        
        geom_point(
            data = q,
            aes(x = POS, y = `Ground Truth ALT`, size = `Ground Truth AF`, fill = "Ground Truth"),
            position = position_nudge(y = .15), shape = 21, stroke = .25
        ) +
        
        geom_point(
            data = q1,
            aes(x = POS, y = `VarDict ALT`, size = `VarDict AF`, fill = "VarDict"),
            position = position_nudge(y = -.15), shape = 21, stroke = .25
        ) +
        
        scale_size_continuous(
            range = c(2, 10), 
            limits = c(0, 1),
            breaks = c(.05, .1, .2, .5, .8),
            labels = scales::percent,
            guide = guide_legend(
                title = "Allele Frequency",
                title.position = "top"
            )
        ) +
        
        scale_fill_manual(
            values = c(
                "Ground Truth" = "#43ae8d",
                "VarDict"      = "#8d43ae"
            ),
            
            guide = guide_legend(
                title = "Category",
                title.position = "top",
                
                override.aes = list(size = 3.5)
            )
        ) +
        
        scale_x_continuous(labels = scales::comma_format(suffix = " bp"), 
                           expand = c(0, 0),
                           limits = c(0, 20000)) +
        
        scale_y_discrete(breaks = c("A", "C", "G", "T")) +
        
        theme_minimal() +
        
        theme(
            legend.position = "bottom",
            
            axis.line.x = element_line(),
            axis.ticks.x = element_line(),
            
            axis.text.y = element_text(face = "bold", size = 13),
            axis.text.x = element_text(face = "bold", size = 11),
            axis.title.y = element_text(face = "bold", size = 13),
            axis.title.x = element_text(face = "bold", size = 13),
            
            panel.grid.minor = element_blank(),
            panel.grid.major.x = element_blank(),
            
            plot.margin = margin(20, 30, 20, 20)
        ) +
        
        labs(
            x = "Chromosomal Position",
            y = "Alterations"
        )
    
    return(o)
    
}


venn_plot_VarDict <- function(q, p) {
    #function to produce Venn plot for each caller
    vcf_GT = vcfR::getFIX(q) |> as.data.frame() |> setDT()
    vcf_GT$scenario = "GT"
    
    vcf_VarDict = vcfR::getFIX(p) |> as.data.frame() |> setDT()
    vcf_VarDict$scenario = "VarDict"
    
    x = rbind(vcf_GT, vcf_VarDict)
    y = x[, c("CHROM", "POS", "REF", "ALT", "scenario"), with = FALSE]
    
    y$mut = paste(y$CHROM, y$POS, y$REF, y$ALT, sep = ":")
    
    y = split(y, y$scenario)
    
    y = list(
        'Ground Truth' = y$GT$mut,
        'VarDict'         = y$VarDict$mut
    )
    
    gr = ggvenn(y, fill_color = c("#43ae8d", "#8d43ae")) +
        
        coord_equal(clip = "off")
    
    return(gr)
}



#FP & FN SNVS------------------------------------------------------------------

load_VarDict_vcf <- function(path, merged_file){
    #function to load caller vcf
    VarDict_somatic_vcf <- read.vcfR( paste0(path, "/",merged_file, 
                                             "_VarDict_norm.vcf"), verbose = FALSE )
    VarDict_s0  = VarDict_somatic_vcf |> vcfR::getFIX() |> as.data.frame() |> setDT()
    #VarDict_s1  = VarDict_somatic_vcf |> extract_gt_tidy() |> setDT()
    VarDict_s2 = VarDict_somatic_vcf |> extract_info_tidy() |> setDT()
    VarDict_s2 = VarDict_s2[,c( "DP", "AF" )]
    VarDict_somatic = cbind(VarDict_s0, VarDict_s2)
    return(VarDict_somatic)
}

fp_snvs_VarDict <- function(VarDict_somatic_snvs, pick_gt, gt_all){
    #find VarDict FP variants
    fp_var = define_fp(VarDict_somatic_snvs, pick_gt)
    fp_var$AF = as.numeric(fp_var$AF)
    colnames(fp_var) = c("CHROM", "POS","ID", "VarDict REF",	
                         "VarDict ALT", "VarDict QUAL",	"VarDict FILTER",
                         "VarDict DP", "VarDict AF", "mut")
    
    #find DP of FP variants'  location in GT
    tmp = gt_all[which(POS %in% unique(fp_var$POS))]
    tmp = tmp[nchar(tmp$REF) == nchar(tmp$ALT)]
    a = unique(tmp, by = "POS")
    #to include the presence multiple variants in a POS
    index = match(fp_var$POS, a$POS)
    fp_var$`Ground Truth DP` = a[index]$DP
    fp_var$`DP Percentage` = fp_var$`VarDict DP`/fp_var$`Ground Truth DP`
    fp_var$type = "FP"
    return(fp_var)
}

final_fp_snvs_VarDict<- function(path, merged_file, pick_gt, gt_all){
    
    VarDict_somatic <- load_VarDict_vcf(path, merged_file)
    VarDict_somatic_snvs <-select_snvs(VarDict_somatic)
    fp_var = fp_snvs_VarDict(VarDict_somatic_snvs, pick_gt, gt_all)
    
    return(fp_var)
}

final_fn_snvs_VarDict<- function(path, merged_file, pick_gt){
    
    VarDict_somatic <- load_VarDict_vcf(path, merged_file)
    VarDict_somatic_snvs <-select_snvs(VarDict_somatic)
    fn_var = define_fn(VarDict_somatic_snvs, pick_gt)
    colnames(fn_var) = c("POS", "Ground Truth REF", "Ground Truth DP", 
                         "Ground Truth ALT", "Count", "Ground Truth AF", "mut", "type")
    
    return(fn_var)
}

fp_violin_plots_VarDict <- function(q) {
    #function to produce variants' barplots for coverage and AF
    #q[which(q$`VarDict ALT` == "")]$`VarDict ALT` = NA
    q$POS = as.numeric(q$POS)
    q$`Ground Truth DP` = as.numeric(q$`Ground Truth DP`)
    q$`VarDict DP` = as.numeric(q$`VarDict DP`)
    
    #DP plot
    df = q[, c(
        "POS", 
        "Ground Truth DP",
        "VarDict DP"
    ), with = FALSE] |>
        unique() |>
        
        melt(id.vars = "POS", variable.factor = FALSE, value.factor = FALSE)
    
    o1 = ggplot(data = df) +
        
        geom_point(aes(x = variable, y = value, fill = variable),
                   position = position_jitternormal(sd_x = .01, sd_y = 0),
                   shape = 21, stroke = .1, size = 2.5) +
        
        geom_violin(aes(x = variable, y = value, fill = variable),
                    width = .25, alpha = .5, outlier.shape = NA) +
        
        scale_fill_manual(
            values = c(
                "Ground Truth DP" = "#43ae8d",
                "VarDict DP"      = "#8d43ae"
            )
        ) +
        
        scale_x_discrete(
            breaks = c("Ground Truth DP", "VarDict DP"),
            labels = c("Ground Truth", "VarDict")
        ) +
        
        scale_y_continuous(labels = scales::comma) +
        
        theme_minimal() +
        
        theme(
            legend.position = "none",
            
            axis.title.x = element_blank(),
            axis.title.y = element_text(face = "bold", size = 13),
            axis.text.x = element_text(face = "bold", size = 13),
            axis.text.y = element_text(face = "bold", size = 13),
            
            axis.line = element_line(),
            axis.ticks = element_line(),
            
            panel.grid = element_blank(),
            
            plot.margin = margin(20, 20, 20, 20)
        ) +
        
        labs(
            y = "Coverage (No. of reads)"
        )
}

fp_af_barplot_VarDict <- function(q){
    #FP AF plot
    df = q[, c(
        "POS",
        "VarDict AF"
    ), with = FALSE] |>
        unique() |>
        
        melt(id.vars = "POS", variable.factor = FALSE, value.factor = FALSE)
    
    o2 = ggplot(data = df[which(!is.na(value) & value != 0)]) +
        
        geom_point(aes(x = variable, y = value, fill = variable),
                   position = position_jitternormal(sd_x = .01, sd_y = 0),
                   shape = 21, stroke = .1, size = 2.5) +
        
        geom_boxplot(aes(x = variable, y = value, fill = variable),
                     width = .25, alpha = .5, outlier.shape = NA) +
        
        scale_fill_manual(
            values = c(
                #"Ground Truth AF" = "#43ae8d",
                "VarDict AF"      = "#8d43ae"
            )
        ) +
        
        scale_x_discrete(
            labels = c("VarDict FP Variants")
        ) +
        
        scale_y_continuous(labels = scales::percent, trans = "log10") +
        
        theme_minimal() +
        
        theme(
            legend.position = "none",
            
            axis.title.x = element_blank(),
            axis.title.y = element_text(face = "bold", size = 13),
            axis.text.x = element_text(face = "bold", size = 13),
            axis.text.y = element_text(face = "bold", size = 13),
            
            axis.line = element_line(),
            axis.ticks = element_line(),
            
            panel.grid = element_blank(),
            
            plot.margin = margin(20, 20, 20, 20)
        ) +
        
        labs(
            y = "Allele Frequency"
        )
    return(o2)
    
}

plot_snvs_FP_VarDict <- function(df, merged_file) {
    #plotting function
    out1 = fp_violin_plots_VarDict(df)
    out2 = fp_af_barplot_VarDict(df)
    
    multi = out1 + out2 +
        
        plot_layout(
            widths = c(1, 1)
        )
    return(multi)
}

#INDELS------------------------------------------------------------------------
categorize_fns_VarDict <- function(caller, fn_var) {
    #function to identify FN categories
    
    caller$POS = as.numeric(caller$POS)
    fn_var$POS = as.numeric(fn_var$POS)
    colnames(fn_var) = c("POS","REF", "Ground Truth DP",  "ALT",
                         "Count", "Ground Truth AF","mut","type")
    #Same POS
    same_POS <- merge(fn_var, caller, by = c("POS"))
    fn_var[, category := ifelse(POS %in% same_POS$POS, "diff REF", "not exist")]
    
    #Same POS & REF
    same_POS_REF <- merge(fn_var, caller, by = c("POS", "REF"))
    # Update only rows where POS and REF match
    fn_var[POS %in% same_POS_REF$POS & REF %in% same_POS_REF$REF, 
           category := "diff ALT"]
    
    return(fn_var)
}

categorize_fps_VarDict <- function(pick_gt_stdz, fp_indels_VarDict) {
    #function to identify FP categories
    pick_gt_stdz$POS = as.numeric(pick_gt_stdz$POS)
    fp_indels_VarDict$POS = as.numeric(fp_indels_VarDict$POS)
    
    colnames(fp_indels_VarDict) = c("CHROM", "POS", "ID", "REF", 
                                    "ALT", "VarDict QUAL", "VarDict FILTER", "VarDict DP", 
                                    "VarDict AF", "mut", "Ground Truth DP","DP Percentage", "type")
    #Same POS
    same_POS <- merge(fp_indels_VarDict, pick_gt_stdz, by = c("POS"))
    fp_indels_VarDict[, category := ifelse(POS %in% same_POS$POS, "diff REF", "not exist")]
    
    #Same POS & REF
    same_POS_REF <- merge(fp_indels_VarDict, pick_gt_stdz, by = c("POS", "REF"))
    # Update only rows where POS and REF match
    fp_indels_VarDict[POS %in% same_POS_REF$POS & REF %in% same_POS_REF$REF, 
                      category := "diff ALT"]
    
    return(fp_indels_VarDict)
}


final_tp_indels_VarDict <- function(path, merged_file, pick_gt_stdz){
    #function to identify TP indels
    VarDict_somatic_indels <- load_VarDict_vcf(path, merged_file) |> select_indels()
    tp_var = define_tp(VarDict_somatic_indels, pick_gt_stdz)
    return(tp_var)
}

final_fn_indels_VarDict <- function(path, merged_file, pick_gt_stdz){
    #function to identify FN indels
    VarDict_somatic_indels <- load_VarDict_vcf(path, merged_file) |> select_indels()
    fn_var = define_fn(VarDict_somatic_indels, pick_gt_stdz)
    colnames(fn_var) = c("POS", "Ground Truth REF", "Ground Truth DP", 
                         "Ground Truth ALT", "Count", "Ground Truth AF", "mut", "type")
    return(fn_var)
}

final_fp_indels_VarDict <- function(path, merged_file, pick_gt, gt_all){
    #function to identify FP indels
    VarDict_somatic_indels <- load_VarDict_vcf(path, merged_file) |> select_indels()
    fp_var = fp_snvs_VarDict(VarDict_somatic_indels, pick_gt, gt_all)
    return(fp_var)
}


call_fn_indels_VarDict <- function(path, merged_file, pick_gt_stdz){
    #function to output categorized FN indels
    fn_indels_VarDict = final_fn_indels_VarDict(path, merged_file, pick_gt_stdz)
    VarDict_indels = load_VarDict_vcf(path, merged_file) |> select_indels()
    fn_indels_VarDict_categories = categorize_fns_VarDict(VarDict_indels, fn_indels_VarDict)
    
    return(fn_indels_VarDict_categories)
}

call_fp_indels_VarDict <- function(path, merged_file, pick_gt_stdz){
    #function to output categorized FP indels
    gt_all = load_gt_report_indels(path, merged_file)$all |> standardize_indels()
    fp_indels_VarDict = final_fp_indels_VarDict(path, merged_file, pick_gt_stdz, gt_all)
    fp_indels_VarDict_categories = categorize_fps_VarDict(pick_gt_stdz, fp_indels_VarDict)
    
    return(fp_indels_VarDict_categories)
}



circular_plot_VarDict <- function(path, merged_file, caller){
    #Load data
    tp = fread(paste0(path, "/", merged_file, "_", caller, "_indels_TP.tsv"), sep = "\t")
    fp = fread(paste0(path, "/", merged_file, "_", caller, "_indels_FP.tsv"), sep = "\t")
    fn = fread(paste0(path, "/", merged_file, "_", caller, "_indels_FN.tsv"), sep = "\t")
    
    tp = tp[, .(POS, REF, ALT, type)]
    tp$REF_len <- str_length(tp$REF)
    tp$ALT_len <- str_length(tp$ALT)
    tp$len_dif <- tp$ALT_len - tp$REF_len
    tp$category <- "not exist"
    
    fp = fp[, .(POS, REF, ALT, type, category)]
    fp$REF_len <- str_length(fp$REF)
    fp$ALT_len <- str_length(fp$ALT)
    fp$len_dif <- fp$ALT_len - fp$REF_len
    
    fn = fn[, .(POS, REF, ALT, type, category)]
    fn$REF_len <- str_length(fn$REF)
    fn$ALT_len <- str_length(fn$ALT)
    fn$len_dif <- fn$ALT_len - fn$REF_len
    
    #Combine the datasets 
    data = rbind(tp, fp)
    df = rbind(data, fn)
    colnames(df) <- c("POS", "REF", "ALT", "Type",  "REF_len", "ALT_len", "len_dif", "Category")
    
    #plot ------------------------------------------------------------------------
    #Adjust data so that each type has its own y-offset
    df <- df |>
        mutate(y_cycle = case_when(
            Type == "FN" ~ len_dif + 50,   # Shift FN cycle outward
            Type == "FP" ~ len_dif + 25,   # Shift FP cycle to middle
            Type == "TP" ~ len_dif         # Keep TP at the center
        ))
    
    #Ensure 'category' is a factor
    df$Category <- factor(df$Category, levels = c("not exist", "diff REF", "diff ALT"))
    df$Type <- factor(df$Type, levels = c("TP", "FP", "FN"))
    
    p <- ggplot(df, aes(x = POS, y = y_cycle)) +
        
        #Lollipop segments: start each from the respective baseline to the point
        geom_segment(
            aes(x = POS, xend = POS,
                y = ifelse(Type == "FN", 50, ifelse(Type == "FP", 25, 0)),
                yend = y_cycle),
            color = "grey75", linewidth = 0.25, lineend = "round"
        ) +
        
        #Dashed lines for separation of each cycle level
        geom_hline(yintercept = 50, color = "grey40") +
        geom_hline(yintercept = 25, color = "grey40") +
        geom_hline(yintercept = 0,  color = "grey40") +
        
        
        # Add points at the end of each segment for the lollipop head
        geom_point(aes(fill = Type, color = Type, shape = Category, 
                       size = ifelse(Category == "not exist", 1.5, 3)), # Increase size for specific categories
                   stroke = .15) +
        
        scale_size_identity() +
        
        #Define specific shapes for each category level
        scale_shape_manual(values = c("diff REF" = 23, "diff ALT" = 24, "not exist" = 21)) +
        
        #Define custom colors for each type
        scale_fill_manual(values = c("TP" = "#7465a2", "FP" = "#8d43ae", "FN" = "#43ae8d")) +
        scale_color_manual(values = c("TP" = "#7465a2", "FP" = "#8d43ae", "FN" = "#43ae8d") |> darken(.25)) +
        
        #Customize the x-axis and radial coordinates
        scale_x_continuous(breaks = c(0, 4751, 9503, 14255, 19007), limits = c(0, 19007)) +
        
        coord_radial(start = pi / 2.5, inner.radius = .25, end = 2.6 * pi) +
        
        #Remove legend for size if unnecessary
        guides(size = "none") +
        
        #Define minimal theme and other plot aesthetics
        theme_minimal() +
        theme(
            axis.text.y = element_blank(),
            panel.grid.major = element_line(linewidth = 0.35),
            panel.grid.minor = element_blank(),
            plot.margin = margin(20, 20, 20, 20),
            plot.title = element_text(size = 15, face = "bold", hjust = 0.5)
        ) +
        
        #Add labels for the plot
        labs(
            title = "Ground Truth vs VarDict INDELS",
            y = "REF vs ALT Length Difference",
            x = "Chromosomal Position"
            #color = "Type",
            #fill = "Type"
        )
    
    return(p)
}