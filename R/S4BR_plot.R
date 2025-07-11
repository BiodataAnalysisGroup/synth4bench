#'A script, written in R, that calls the appropriate functions to make 
#'visualizations to illustrate the comparison between the ground truth 
#'and the caller.
#'
#'Input files: a tsv file with the comparison between the ground truth 
#'and the caller, ground truth vcf file, caller vcf file
#'
#'Output files: multi planel figure and a Venn plot
#'
#'Authors: Nikos Pechlivanis(github:npechl),Stella Fragkouli(sfragkoul), 
#'Natasa Anastasiadou(natanast)
#' 


#!/usr/bin/env Rscript
message("Loading Libraries...")
source("R/libraries.R")

source("R/viz_common_helpers.R")
source("R/viz_gatk_helpers.R")
source("R/viz_Freebayes_helpers.R")
source("R/viz_VarDict_helpers.R")
source("R/viz_VarScan_helpers.R")
source("R/viz_LoFreq_helpers.R")

#Parse arguments from command line
options <- list(
  # make_option(c("-t", "--gt_comparison"), 
  #             action = "store", 
  #             type = "character", 
  #             help="Directory path where Ground Truth vs Caller file tsv file is 
  #             located."),
  
  # make_option(c("-v", "--vcf_path"), 
  #             action = "store", 
  #             type = "character", 
  #             help="Directory path where VCF files are located."),
  
  # make_option(c("-g", "--gt_path"), 
  #             action = "store", 
  #             type = "character", 
  #             help="Directory path where ground truth vcf file is located."),
  
  make_option(c("-c", "--caller"), 
              action = "store", 
              type = "character", 
              help="Choose caller name (Freebayes, Mutect2, LoFreq, VarDict, VarScan)"),
  
  make_option(c("-w", "--working_directory"), 
              action = "store", 
              type = "character", 
              help="Path of working directory were all files are located and the results will be generated."),
  
  make_option(c("-m", "--merged_file"), 
              action = "store", 
              type = "character", 
              help="Indicate the name given to the final merged ground truth file.")
)

arguments <- parse_args(OptionParser(option_list = options))
arguments$gt_comparison <- arguments$working_directory
arguments$vcf_path <- arguments$working_directory
arguments$gt_path <- arguments$working_directory


#SNVs -------------------------------------------------------------------------
print("Plotting SNVs TP Variants")
plots_snvs_TP <- plot_snvs_TP(arguments$gt_comparison,
                          arguments$caller,
                          arguments$merged_file)

dir.create(paste0(arguments$working_directory, "/Plots"))

ggsave(
  plot = plots_snvs_TP, filename = paste0(arguments$working_directory,
                                       "/Plots/",
                                       arguments$merged_file, "_",
                                       arguments$caller,
                                       "_snvs_TV.png"),
  width = 16, height = 12, units = "in", dpi = 600
)

print("Plotting Noise FP Variants")
plots_snvs_FP <- plot_snvs_FP(arguments$gt_comparison,
                              arguments$caller,
                              arguments$merged_file)

ggsave(
    plot = plots_snvs_FP, filename = paste0(arguments$gt_comparison,
                                                 "/Plots/",
                                                 arguments$merged_file, "_",
                                                 arguments$caller,
                                                 "_snvs_Noise_FP.png"),
    width = 16, height = 12, units = "in", dpi = 600
)


print("Plotting Noise FN Variants")
plots_snvs_FN <- plot_snvs_FN(arguments$gt_comparison,
                              arguments$caller,
                              arguments$merged_file)

ggsave(
    plot = plots_snvs_FN, filename = paste0(arguments$gt_comparison,
                                            "/Plots/",
                                            arguments$merged_file, "_",
                                            arguments$caller,
                                            "_snvs_Noise_FN.png"),
    width = 16, height = 12, units = "in", dpi = 600
)

print("Plotting Noise TP Variants")
plots_snvs_TP <- plot_snvs_noise_TP(arguments$gt_comparison,
                              arguments$caller,
                              arguments$merged_file)

ggsave(
    plot = plots_snvs_TP, filename = paste0(arguments$gt_comparison,
                                            "/Plots/",
                                            arguments$merged_file, "_",
                                            arguments$caller,
                                            "_snvs_Noise_TP.png"),
    width = 16, height = 12, units = "in", dpi = 600
)

# #INDELs ---------------------------------------------------------------------
print("Plotting INDELs")
indel_plots <- plot_indels(arguments$gt_comparison,
                           arguments$merged_file,
                           arguments$caller)

ggsave(
    plot = indel_plots, filename = paste0(arguments$gt_comparison,
                                            "/Plots/",
                                            arguments$merged_file, "_",
                                            arguments$caller,
                                            "_indels.png"),
    width = 14, height = 12, units = "in", dpi = 600
)

print("Plotting Completed")

