################################################################################
##  processing_bayesian_output.R: Compiles Bayesian output and makes figures for the primary analysis of richness and compositonal differences between treatment and control plots for datasets cut off at 20 years.
##
##  Author: Kimberly Komatsu
##  Date created: January 17, 2018
##  See https://github.com/klapierre/Converge_Diverge/blob/master/core%20data%20paper_bayesian%20results_figures_sig%20test_expinteractions_20yr.R for full history.
################################################################################

library(grid)
library(tidyverse)

#kim laptop
setwd("C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\datasets\\LongForm")

#kim desktop
setwd("C:\\Users\\la pierrek\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\datasets\\LongForm")

theme_set(theme_bw())
theme_update(axis.title.x=element_text(size=40, vjust=-0.35, margin=margin(t=15)), axis.text.x=element_text(size=34, color='black'),
             axis.title.y=element_text(size=40, angle=90, vjust=0.5, margin=margin(r=15)), axis.text.y=element_text(size=34, color='black'),
             plot.title = element_text(size=40, vjust=2),
             panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
             legend.title=element_blank(), legend.text=element_text(size=20))


###bar graph summary statistics function
#barGraphStats(data=, variable="", byFactorNames=c(""))
barGraphStats <- function(data, variable, byFactorNames) {
  count <- length(byFactorNames)
  N <- aggregate(data[[variable]], data[byFactorNames], FUN=length)
  names(N)[1:count] <- byFactorNames
  names(N) <- sub("^x$", "N", names(N))
  mean <- aggregate(data[[variable]], data[byFactorNames], FUN=mean)
  names(mean)[1:count] <- byFactorNames
  names(mean) <- sub("^x$", "mean", names(mean))
  sd <- aggregate(data[[variable]], data[byFactorNames], FUN=sd)
  names(sd)[1:count] <- byFactorNames
  names(sd) <- sub("^x$", "sd", names(sd))
  preSummaryStats <- merge(N, mean, by=byFactorNames)
  finalSummaryStats <- merge(preSummaryStats, sd, by=byFactorNames)
  finalSummaryStats$se <- finalSummaryStats$sd / sqrt(finalSummaryStats$N)
  return(finalSummaryStats)
}

#function to get standard deviations of columns in a dataframe
colSd <- function (x, na.rm=FALSE) apply(X=x, MARGIN=2, FUN=sd, na.rm=na.rm)

##################################################################################
##################################################################################
#import experiment information --------------------------------------------------------
expRaw <- read.csv('ExperimentInformation_March2019.csv')


expInfo <- expRaw%>%
  #remove any pre-treatment data for the few experiments that have it -- pre-treatment data for experiments is awesome and we should all strive to collect it!
  filter(treatment_year!=0)%>%
  #make columns for irrigation and drought from precip column
  group_by(site_code, project_name, community_type, treatment)%>%
  mutate(irrigation=ifelse(precip>0, 1, 0), drought=ifelse(precip<0, 1, 0))%>%
  #calcualte minumum years for each project
  summarise(min_year=min(treatment_year), nutrients=mean(nutrients), water=mean(water), carbon=mean(carbon), irrigation=mean(irrigation), drought=mean(drought), experiment_length=max(treatment_year))

#import treatment data
trtInfo1 <- read.csv('ExperimentInformation_March2019.csv')

#import diversity metrics that went into Bayesian analysis
rawData <- read.csv('ForAnalysis_allAnalysisAllDatasets_04082019.csv')

#calculate means and standard deviations across all data for richness and compositonal differences to backtransform
rawData2<- rawData%>%
  left_join(trtInfo1)%>%
  filter(anpp!='NA', treatment_year!=0)%>%
  summarise(mean_mean=mean(composition_diff), std_mean=sd(composition_diff), mean_rich=mean(S_lnRR), std_rich=sd(S_lnRR), mean_eH=mean(expH_lnRR), std_eH=sd(expH_lnRR), mean_PC=mean(S_PC), std_PC=sd(S_PC)) #to backtransform

#select just data in this analysis
expInfo2 <- rawData%>%
  left_join(trtInfo1)%>%
  filter(anpp!='NA', treatment_year!=0)%>%
  group_by(site_code, project_name, community_type, treatment)%>%
  summarise(experiment_length=mean(experiment_length))

#for table of experiment summarizing various factors
expInfoSummary <- rawData%>%
  left_join(trtInfo1)%>%
  filter(anpp!='NA', treatment_year!=0)%>%
  group_by(site_code, project_name, community_type, treatment)%>%
  summarise(experiment_length=mean(experiment_length), plot_mani=mean(plot_mani), rrich=mean(rrich), anpp=mean(anpp), MAT=mean(MAT), MAP=mean(MAP))%>%
  ungroup()%>%
  summarise(length_mean=mean(experiment_length), length_min=min(experiment_length), length_max=max(experiment_length),
            plot_mani_median=mean(plot_mani), plot_mani_min=min(plot_mani), plot_mani_max=max(plot_mani),
            rrich_mean=mean(rrich), rrich_min=min(rrich), rrich_max=max(rrich),
            anpp_mean=mean(anpp), anpp_min=min(anpp), anpp_max=max(anpp),
            MAP_mean=mean(MAP), MAP_min=min(MAP), MAP_max=max(MAP),
            MAT_mean=mean(MAT), MAT_min=min(MAT), MAT_max=max(MAT))%>%
  gather(variable, estimate)

#treatment info
trtInfo2 <- trtInfo1%>%
  select(site_code, project_name, community_type, treatment, plot_mani, trt_type)%>%
  unique()
  
trtInfo <- rawData%>%
  select(site_code, project_name, community_type, treatment, trt_type, experiment_length, rrich, anpp, MAT, MAP)%>%
  unique()%>%
  left_join(expInfo)

mean(expInfo$experiment_length) #8.963333
median(expInfo$experiment_length) #7


################################################################################
################################################################################
# ###Bayesian output processing
# 
# #only run to generate initial chains files


###N(0,1) priors---------------------------------------
#raw chains data
memory.limit(size=50000)
chains1 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\N01_lnRR_all years\\N01-timestdbytrt_lnRR_0.csv', comment.char='#')
chains1 <- chains1[-1:-5000,]
chains2 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\N01_lnRR_all years\\N01-timestdbytrt_lnRR_1.csv', comment.char='#')
chains2 <- chains2[-1:-5000,]
chains3 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\N01_lnRR_all years\\N01-timestdbytrt_lnRR_2.csv', comment.char='#')
chains3 <- chains3[-1:-5000,]
chains4 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\N01_lnRR_all years\\N01-timestdbytrt_lnRR_3.csv', comment.char='#')
chains4 <- chains4[-1:-5000,]

chainsCommunity <- rbind(chains1, chains2, chains3, chains4)


#density plot of chains
plot(density(chainsCommunity$D.1.1.1))
plot(density(chainsCommunity$D.1.1.2))
plot(density(chainsCommunity$D.1.1.3))


#get values for overall (mean) lines across levels of plot mani
#mean change are the 1's, richness are the 2's
chainsCommunity2 <- chainsCommunity%>%
  select(lp__,
         #trt_type intercepts: center digit refers to trts
         E.1.1.1, E.2.1.1, E.1.2.1, E.2.2.1, E.1.3.1, E.2.3.1, E.1.4.1, E.2.4.1, E.1.5.1, E.2.5.1,
         E.1.6.1, E.2.6.1, E.1.7.1, E.2.7.1, E.1.8.1, E.2.8.1, E.1.9.1, E.2.9.1, E.1.10.1, E.2.10.1,
         E.1.11.1, E.2.11.1, E.1.12.1, E.2.12.1, E.1.13.1, E.2.13.1, E.1.14.1, E.2.14.1, E.1.15.1, E.2.15.1,
         E.1.16.1, E.2.16.1,
         #trt_type linear slopes: center digit refers to trts
         E.1.1.2, E.2.1.2, E.1.2.2, E.2.2.2, E.1.3.2, E.2.3.2, E.1.4.2, E.2.4.2, E.1.5.2, E.2.5.2,
         E.1.6.2, E.2.6.2, E.1.7.2, E.2.7.2, E.1.8.2, E.2.8.2, E.1.9.2, E.2.9.2, E.1.10.2, E.2.10.2,
         E.1.11.2, E.2.11.2, E.1.12.2, E.2.12.2, E.1.13.2, E.2.13.2, E.1.14.2, E.2.14.2, E.1.15.2, E.2.15.2,
         E.1.16.2, E.2.16.2,
         #trt_type quadratic slopes: center digit refers to trts and interactions with anpp and gamma diversity
         E.1.1.3, E.2.1.3, E.1.2.3, E.2.2.3, E.1.3.3, E.2.3.3, E.1.4.3, E.2.4.3, E.1.5.3, E.2.5.3,
         E.1.6.3, E.2.6.3, E.1.7.3, E.2.7.3, E.1.8.3, E.2.8.3, E.1.9.3, E.2.9.3, E.1.10.3, E.2.10.3,
         E.1.11.3, E.2.11.3, E.1.12.3, E.2.12.3, E.1.13.3, E.2.13.3, E.1.14.3, E.2.14.3, E.1.15.3, E.2.15.3,
         E.1.16.3, E.2.16.3,
         #ANPP intercept, linear, and quad slopes (center digit): 2=anpp
         D.1.2.1, D.2.2.1,
         D.1.2.2, D.2.2.2,
         D.1.2.3, D.2.2.3,
         #richness intercept, linear, and quad slopes (center digit): 3=gamma diversity
         D.1.3.1, D.2.3.1,
         D.1.3.2, D.2.3.2,
         D.1.3.3, D.2.3.3,
         #overall intercept, linear, and quad slopes (center digit): 1=overall
         D.1.1.1, D.2.1.1,
         D.1.1.2, D.2.1.2,
         D.1.1.3, D.2.1.3)%>%
  gather(key=parameter, value=value, E.1.1.1:D.2.1.3)%>%
  group_by(parameter)%>%
  summarise(median=median(value), sd=sd(value))%>%
  mutate(lower=median-2*sd, upper=median+2*sd, lower_sign=sign(lower), upper_sign=sign(upper), diff=lower_sign-upper_sign, median=ifelse(diff==-2, 0, median))

# write.csv(chainsCommunity2, 'stdtimebytrt_N01_summary_04092019.csv')


#gather the intercepts, linear slopes, and quadratic slopes for all treatments
#numbers are B.variable.number.parameter (e.g., B.mean.87.slope)
#variable (second place): 1=mean change, 2=richness change
#parameter (final digit): 1=intercept, 2=linear slope, 3=quad slope
#set any that are not significant (CI overlaps 0) as 0

#get mean parameter values across all runs for each experiment, treatment, etc
chainsFinalMean <- as.data.frame(colMeans(chainsCommunity[,8918:11545]))%>% #may need to delete original four chains dataframes to get this to work
  add_rownames('parameter')
names(chainsFinalMean)[names(chainsFinalMean) == 'colMeans(chainsCommunity[, 8918:11545])'] <- 'mean'
#get sd of parameter values across all runs for each experiment, treatment, etc
chainsFinalSD <- as.data.frame(colSd(chainsCommunity[,8918:11545]))
names(chainsFinalSD)[names(chainsFinalSD) == 'colSd(chainsCommunity[, 8918:11545])'] <- 'sd'

chainsFinal <- cbind(chainsFinalMean, chainsFinalSD)%>%
  #split names into parts
  separate(parameter, c('B', 'variable', 'id', 'parameter'))%>%
  select(-B)%>%
  #rename parts to be more clear
  mutate(variable=ifelse(variable==1, 'mean', 'richness'),
         parameter=ifelse(parameter==1, 'intercept', ifelse(parameter==2, 'linear', 'quadratic')),
         id=as.integer(id))%>%
  #if 95% confidence interval overlaps 0, then set mean to 0
  mutate(lower=mean-2*sd, upper=mean+2*sd, lower_sign=sign(lower), upper_sign=sign(upper), diff=lower_sign-upper_sign, mean=ifelse(diff==-2, 0, mean))%>%
  #spread by variable
  select(variable, id, parameter, mean)%>%
  spread(key=parameter, value=mean)

# write.csv(chainsFinal, 'stdtimebytrt_N01_means_04092019.csv')


#don't set mean to 0 to address reviewer 1 comments (for example only, but for main figures we set non-sig parameters to 0)
chainsFinalAlt <- cbind(chainsFinalMean, chainsFinalSD)%>%
  #split names into parts
  separate(parameter, c('B', 'variable', 'id', 'parameter'))%>%
  select(-B)%>%
  #rename parts to be more clear
  mutate(variable=ifelse(variable==1, 'mean', 'richness'),
         parameter=ifelse(parameter==1, 'intercept', ifelse(parameter==2, 'linear', 'quadratic')),
         id=as.integer(id))%>%
  mutate(lower=mean-2*sd, upper=mean+2*sd, lower_sign=sign(lower), upper_sign=sign(upper), diff=lower_sign-upper_sign)%>%
  #spread by variable
  select(variable, id, parameter, mean)%>%
  spread(key=parameter, value=mean)

# write.csv(chainsFinalAlt, 'stdtimebytrt_N01_means_not0_04092019.csv')


#merge together with experiment list
trtID <- read.csv('bayesian_trt_index.csv')%>%
  select(site_code, project_name, community_type, treatment, treat_INT)%>%
  unique()%>%
  rename(id=treat_INT)
timeStd <- read.csv('bayesian_trt_index.csv')%>%
  group_by(comm_INT, treat_INT)%>%
  summarise(time_mean=mean(time), time_std=sd(time))%>%
  ungroup()%>%
  rename(id=treat_INT)
chainsExperiment <- chainsFinal%>%
  left_join(trtID)%>%
  left_join(trtInfo)%>%
  left_join(timeStd)

#generate equations for main figure of richness and compositional responses through time
chainsEquations <- chainsExperiment%>%
  #get standardized experiment length
  mutate(alt_length=experiment_length - min_year)%>%
  # mutate(alt_length=ifelse(alt_length>=20, 19, alt_length))%>%
  # mutate(color=ifelse(rrich<31, '#1104DC44', ifelse(rrich<51&rrich>30, '#4403AE55', ifelse(rrich<71&rrich>50, '#77038166', ifelse(rrich>70, '#DD032688', 'grey')))))%>%
  mutate(curve1='stat_function(fun=function(x){(',
         curve2=' + ',
         curve3='*((x-',
         curve4=')/',
         curve5=') + ',
         curve6='*((x-',
         curve7=')/',
         curve8=ifelse(variable=='mean', ')^2)*(0.1860342)+(0.3070874)}, size=2, xlim=c(0,',
                       ')^2)*(0.340217)+(-0.1183477)}, size=2, xlim=c(0,'),
         curve9=')) +',
         curve=paste(curve1, intercept, curve2, linear, curve3, time_mean, curve4, time_std, curve5, quadratic, curve6, time_mean, curve7, time_std, curve8, alt_length, curve9, sep=''))
  # mutate(trt_overall=ifelse(trt_type=='CO2'|trt_type=='N'|trt_type=='P'|trt_type=='drought'|trt_type=='irr'|trt_type=='precip_vari', 'single_resource', ifelse(trt_type=='burn'|trt_type=='mow_clip'|trt_type=='herb_rem'|trt_type=='temp'|trt_type=='plant_mani', 'single_nonresource', ifelse(trt_type=='all_resource'|trt_type=='both', 'three_way', 'two_way'))))

#export, group by shape type, and paste lines below
# write.csv(chainsEquations,'stdtimebytrt_N01_equations_04092019.csv', row.names=F)




###noninformative priors------------------------------------------
#raw chains data
memory.limit(size=50000)
chains1 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\noninf_lnRR_all years\\noninf-timestdbytrt_lnRR_0.csv', comment.char='#')
chains1 <- chains1[-1:-5000,]
chains2 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\noninf_lnRR_all years\\noninf-timestdbytrt_lnRR_1.csv', comment.char='#')
chains2 <- chains2[-1:-5000,]
chains3 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\noninf_lnRR_all years\\noninf-timestdbytrt_lnRR_2.csv', comment.char='#')
chains3 <- chains3[-1:-5000,]
chains4 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\noninf_lnRR_all years\\noninf-timestdbytrt_lnRR_3.csv', comment.char='#')
chains4 <- chains4[-1:-5000,]

chainsCommunity <- rbind(chains1, chains2, chains3, chains4)


#density plot of chains
plot(density(chainsCommunity$D.1.1.1))
plot(density(chainsCommunity$D.1.1.2))
plot(density(chainsCommunity$D.1.1.3))


#get values for overall (mean) lines across levels of plot mani
#mean change are the 1's, richness are the 2's
chainsCommunity2 <- chainsCommunity%>%
  select(lp__,
         #trt_type intercepts: center digit refers to trts
         E.1.1.1, E.2.1.1, E.1.2.1, E.2.2.1, E.1.3.1, E.2.3.1, E.1.4.1, E.2.4.1, E.1.5.1, E.2.5.1,
         E.1.6.1, E.2.6.1, E.1.7.1, E.2.7.1, E.1.8.1, E.2.8.1, E.1.9.1, E.2.9.1, E.1.10.1, E.2.10.1,
         E.1.11.1, E.2.11.1, E.1.12.1, E.2.12.1, E.1.13.1, E.2.13.1, E.1.14.1, E.2.14.1, E.1.15.1, E.2.15.1,
         E.1.16.1, E.2.16.1,
         #trt_type linear slopes: center digit refers to trts
         E.1.1.2, E.2.1.2, E.1.2.2, E.2.2.2, E.1.3.2, E.2.3.2, E.1.4.2, E.2.4.2, E.1.5.2, E.2.5.2,
         E.1.6.2, E.2.6.2, E.1.7.2, E.2.7.2, E.1.8.2, E.2.8.2, E.1.9.2, E.2.9.2, E.1.10.2, E.2.10.2,
         E.1.11.2, E.2.11.2, E.1.12.2, E.2.12.2, E.1.13.2, E.2.13.2, E.1.14.2, E.2.14.2, E.1.15.2, E.2.15.2,
         E.1.16.2, E.2.16.2,
         #trt_type quadratic slopes: center digit refers to trts and interactions with anpp and gamma diversity
         E.1.1.3, E.2.1.3, E.1.2.3, E.2.2.3, E.1.3.3, E.2.3.3, E.1.4.3, E.2.4.3, E.1.5.3, E.2.5.3,
         E.1.6.3, E.2.6.3, E.1.7.3, E.2.7.3, E.1.8.3, E.2.8.3, E.1.9.3, E.2.9.3, E.1.10.3, E.2.10.3,
         E.1.11.3, E.2.11.3, E.1.12.3, E.2.12.3, E.1.13.3, E.2.13.3, E.1.14.3, E.2.14.3, E.1.15.3, E.2.15.3,
         E.1.16.3, E.2.16.3,
         #ANPP intercept, linear, and quad slopes (center digit): 2=anpp
         D.1.2.1, D.2.2.1,
         D.1.2.2, D.2.2.2,
         D.1.2.3, D.2.2.3,
         #richness intercept, linear, and quad slopes (center digit): 3=gamma diversity
         D.1.3.1, D.2.3.1,
         D.1.3.2, D.2.3.2,
         D.1.3.3, D.2.3.3,
         #overall intercept, linear, and quad slopes (center digit): 1=overall
         D.1.1.1, D.2.1.1,
         D.1.1.2, D.2.1.2,
         D.1.1.3, D.2.1.3)%>%
  gather(key=parameter, value=value, E.1.1.1:D.2.1.3)%>%
  group_by(parameter)%>%
  summarise(median=median(value), sd=sd(value))%>%
  mutate(lower=median-2*sd, upper=median+2*sd, lower_sign=sign(lower), upper_sign=sign(upper), diff=lower_sign-upper_sign, median=ifelse(diff==-2, 0, median))

# write.csv(chainsCommunity2, 'stdtimebytrt_noninf_summary_04092019.csv')


#gather the intercepts, linear slopes, and quadratic slopes for all treatments
#numbers are B.variable.number.parameter (e.g., B.mean.87.slope)
#variable (second place): 1=mean change, 2=richness change
#parameter (final digit): 1=intercept, 2=linear slope, 3=quad slope
#set any that are not significant (CI overlaps 0) as 0

#get mean parameter values across all runs for each experiment, treatment, etc
chainsFinalMean <- as.data.frame(colMeans(chainsCommunity[,8918:11545]))%>% #may need to delete original four chains dataframes to get this to work
  add_rownames('parameter')
names(chainsFinalMean)[names(chainsFinalMean) == 'colMeans(chainsCommunity[, 8918:11545])'] <- 'mean'
#get sd of parameter values across all runs for each experiment, treatment, etc
chainsFinalSD <- as.data.frame(colSd(chainsCommunity[,8918:11545]))
names(chainsFinalSD)[names(chainsFinalSD) == 'colSd(chainsCommunity[, 8918:11545])'] <- 'sd'

chainsFinal <- cbind(chainsFinalMean, chainsFinalSD)%>%
  #split names into parts
  separate(parameter, c('B', 'variable', 'id', 'parameter'))%>%
  select(-B)%>%
  #rename parts to be more clear
  mutate(variable=ifelse(variable==1, 'mean', 'richness'),
         parameter=ifelse(parameter==1, 'intercept', ifelse(parameter==2, 'linear', 'quadratic')),
         id=as.integer(id))%>%
  #if 95% confidence interval overlaps 0, then set mean to 0
  mutate(lower=mean-2*sd, upper=mean+2*sd, lower_sign=sign(lower), upper_sign=sign(upper), diff=lower_sign-upper_sign, mean=ifelse(diff==-2, 0, mean))%>%
  #spread by variable
  select(variable, id, parameter, mean)%>%
  spread(key=parameter, value=mean)

# write.csv(chainsFinal, 'stdtimebytrt_noninf_means_04092019.csv')


#merge together with experiment list
trtID <- read.csv('bayesian_trt_index.csv')%>%
  select(site_code, project_name, community_type, treatment, treat_INT)%>%
  unique()%>%
  rename(id=treat_INT)
timeStd <- read.csv('bayesian_trt_index.csv')%>%
  group_by(comm_INT, treat_INT)%>%
  summarise(time_mean=mean(time), time_std=sd(time))%>%
  ungroup()%>%
  rename(id=treat_INT)
chainsExperiment <- chainsFinal%>%
  left_join(trtID)%>%
  left_join(trtInfo)%>%
  left_join(timeStd)

#generate equations for main figure of richness and compositional responses through time
chainsEquations <- chainsExperiment%>%
  #get standardized experiment length
  mutate(alt_length=experiment_length - min_year)%>%
  # mutate(alt_length=ifelse(alt_length>=20, 19, alt_length))%>%
  # mutate(color=ifelse(rrich<31, '#1104DC44', ifelse(rrich<51&rrich>30, '#4403AE55', ifelse(rrich<71&rrich>50, '#77038166', ifelse(rrich>70, '#DD032688', 'grey')))))%>%
  mutate(curve1='stat_function(fun=function(x){(',
         curve2=' + ',
         curve3='*((x-',
         curve4=')/',
         curve5=') + ',
         curve6='*((x-',
         curve7=')/',
         curve8=ifelse(variable=='mean', ')^2)*(0.1860342)+(0.3070874)}, size=2, xlim=c(0,',
                       ')^2)*(0.340217)+(-0.1183477)}, size=2, xlim=c(0,'),
         curve9=')) +',
         curve=paste(curve1, intercept, curve2, linear, curve3, time_mean, curve4, time_std, curve5, quadratic, curve6, time_mean, curve7, time_std, curve8, alt_length, curve9, sep=''))
# mutate(trt_overall=ifelse(trt_type=='CO2'|trt_type=='N'|trt_type=='P'|trt_type=='drought'|trt_type=='irr'|trt_type=='precip_vari', 'single_resource', ifelse(trt_type=='burn'|trt_type=='mow_clip'|trt_type=='herb_rem'|trt_type=='temp'|trt_type=='plant_mani', 'single_nonresource', ifelse(trt_type=='all_resource'|trt_type=='both', 'three_way', 'two_way'))))

#export, group by shape type, and paste lines below
# write.csv(chainsEquations,'stdtimebytrt_noninf_equations_04092019.csv', row.names=F)





###eH as richness metric, N(0,1) priors------------------------------------------
#raw chains data
memory.limit(size=50000)
chains1 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\eH_lnRR_all years\\eH-timestdbytrt_lnRR_0.csv', comment.char='#')
chains1 <- chains1[-1:-5000,]
chains2 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\eH_lnRR_all years\\eH-timestdbytrt_lnRR_1.csv', comment.char='#')
chains2 <- chains2[-1:-5000,]
chains3 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\eH_lnRR_all years\\eH-timestdbytrt_lnRR_2.csv', comment.char='#')
chains3 <- chains3[-1:-5000,]
chains4 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\eH_lnRR_all years\\eH-timestdbytrt_lnRR_3.csv', comment.char='#')
chains4 <- chains4[-1:-5000,]

chainsCommunity <- rbind(chains1, chains2, chains3, chains4)


#density plot of chains
plot(density(chainsCommunity$D.1.1.1))
plot(density(chainsCommunity$D.1.1.2))
plot(density(chainsCommunity$D.1.1.3))


#get values for overall (mean) lines across levels of plot mani
#mean change are the 1's, richness are the 2's
chainsCommunity2 <- chainsCommunity%>%
  select(lp__,
         #trt_type intercepts: center digit refers to trts
         E.1.1.1, E.2.1.1, E.1.2.1, E.2.2.1, E.1.3.1, E.2.3.1, E.1.4.1, E.2.4.1, E.1.5.1, E.2.5.1,
         E.1.6.1, E.2.6.1, E.1.7.1, E.2.7.1, E.1.8.1, E.2.8.1, E.1.9.1, E.2.9.1, E.1.10.1, E.2.10.1,
         E.1.11.1, E.2.11.1, E.1.12.1, E.2.12.1, E.1.13.1, E.2.13.1, E.1.14.1, E.2.14.1, E.1.15.1, E.2.15.1,
         E.1.16.1, E.2.16.1,
         #trt_type linear slopes: center digit refers to trts
         E.1.1.2, E.2.1.2, E.1.2.2, E.2.2.2, E.1.3.2, E.2.3.2, E.1.4.2, E.2.4.2, E.1.5.2, E.2.5.2,
         E.1.6.2, E.2.6.2, E.1.7.2, E.2.7.2, E.1.8.2, E.2.8.2, E.1.9.2, E.2.9.2, E.1.10.2, E.2.10.2,
         E.1.11.2, E.2.11.2, E.1.12.2, E.2.12.2, E.1.13.2, E.2.13.2, E.1.14.2, E.2.14.2, E.1.15.2, E.2.15.2,
         E.1.16.2, E.2.16.2,
         #trt_type quadratic slopes: center digit refers to trts and interactions with anpp and gamma diversity
         E.1.1.3, E.2.1.3, E.1.2.3, E.2.2.3, E.1.3.3, E.2.3.3, E.1.4.3, E.2.4.3, E.1.5.3, E.2.5.3,
         E.1.6.3, E.2.6.3, E.1.7.3, E.2.7.3, E.1.8.3, E.2.8.3, E.1.9.3, E.2.9.3, E.1.10.3, E.2.10.3,
         E.1.11.3, E.2.11.3, E.1.12.3, E.2.12.3, E.1.13.3, E.2.13.3, E.1.14.3, E.2.14.3, E.1.15.3, E.2.15.3,
         E.1.16.3, E.2.16.3,
         #ANPP intercept, linear, and quad slopes (center digit): 2=anpp
         D.1.2.1, D.2.2.1,
         D.1.2.2, D.2.2.2,
         D.1.2.3, D.2.2.3,
         #richness intercept, linear, and quad slopes (center digit): 3=gamma diversity
         D.1.3.1, D.2.3.1,
         D.1.3.2, D.2.3.2,
         D.1.3.3, D.2.3.3,
         #overall intercept, linear, and quad slopes (center digit): 1=overall
         D.1.1.1, D.2.1.1,
         D.1.1.2, D.2.1.2,
         D.1.1.3, D.2.1.3)%>%
  gather(key=parameter, value=value, E.1.1.1:D.2.1.3)%>%
  group_by(parameter)%>%
  summarise(median=median(value), sd=sd(value))%>%
  mutate(lower=median-2*sd, upper=median+2*sd, lower_sign=sign(lower), upper_sign=sign(upper), diff=lower_sign-upper_sign, median=ifelse(diff==-2, 0, median))

# write.csv(chainsCommunity2, 'stdtimebytrt_eH_summary_04092019.csv')


#gather the intercepts, linear slopes, and quadratic slopes for all treatments
#numbers are B.variable.number.parameter (e.g., B.mean.87.slope)
#variable (second place): 1=mean change, 2=richness change
#parameter (final digit): 1=intercept, 2=linear slope, 3=quad slope
#set any that are not significant (CI overlaps 0) as 0

#get mean parameter values across all runs for each experiment, treatment, etc
chainsFinalMean <- as.data.frame(colMeans(chainsCommunity[,8918:11545]))%>% #may need to delete original four chains dataframes to get this to work
  add_rownames('parameter')
names(chainsFinalMean)[names(chainsFinalMean) == 'colMeans(chainsCommunity[, 8918:11545])'] <- 'mean'
#get sd of parameter values across all runs for each experiment, treatment, etc
chainsFinalSD <- as.data.frame(colSd(chainsCommunity[,8918:11545]))
names(chainsFinalSD)[names(chainsFinalSD) == 'colSd(chainsCommunity[, 8918:11545])'] <- 'sd'

chainsFinal <- cbind(chainsFinalMean, chainsFinalSD)%>%
  #split names into parts
  separate(parameter, c('B', 'variable', 'id', 'parameter'))%>%
  select(-B)%>%
  #rename parts to be more clear
  mutate(variable=ifelse(variable==1, 'mean', 'richness'),
         parameter=ifelse(parameter==1, 'intercept', ifelse(parameter==2, 'linear', 'quadratic')),
         id=as.integer(id))%>%
  #if 95% confidence interval overlaps 0, then set mean to 0
  mutate(lower=mean-2*sd, upper=mean+2*sd, lower_sign=sign(lower), upper_sign=sign(upper), diff=lower_sign-upper_sign, mean=ifelse(diff==-2, 0, mean))%>%
  #spread by variable
  select(variable, id, parameter, mean)%>%
  spread(key=parameter, value=mean)

# write.csv(chainsFinal, 'stdtimebytrt_eH_means_04092019.csv')


#merge together with experiment list
trtID <- read.csv('bayesian_trt_index.csv')%>%
  select(site_code, project_name, community_type, treatment, treat_INT)%>%
  unique()%>%
  rename(id=treat_INT)
timeStd <- read.csv('bayesian_trt_index.csv')%>%
  group_by(comm_INT, treat_INT)%>%
  summarise(time_mean=mean(time), time_std=sd(time))%>%
  ungroup()%>%
  rename(id=treat_INT)
chainsExperiment <- chainsFinal%>%
  left_join(trtID)%>%
  left_join(trtInfo)%>%
  left_join(timeStd)

#generate equations for main figure of richness and compositional responses through time
chainsEquations <- chainsExperiment%>%
  #get standardized experiment length
  mutate(alt_length=experiment_length - min_year)%>%
  # mutate(alt_length=ifelse(alt_length>=20, 19, alt_length))%>%
  # mutate(color=ifelse(rrich<31, '#1104DC44', ifelse(rrich<51&rrich>30, '#4403AE55', ifelse(rrich<71&rrich>50, '#77038166', ifelse(rrich>70, '#DD032688', 'grey')))))%>%
  mutate(curve1='stat_function(fun=function(x){(',
         curve2=' + ',
         curve3='*((x-',
         curve4=')/',
         curve5=') + ',
         curve6='*((x-',
         curve7=')/',
         curve8=ifelse(variable=='mean', ')^2)*(0.1860342)+(0.3070874)}, size=2, xlim=c(0,',
                       ')^2)*(0.33205)+(-0.09101243)}, size=2, xlim=c(0,'),
         curve9=')) +',
         curve=paste(curve1, intercept, curve2, linear, curve3, time_mean, curve4, time_std, curve5, quadratic, curve6, time_mean, curve7, time_std, curve8, alt_length, curve9, sep=''))
# mutate(trt_overall=ifelse(trt_type=='CO2'|trt_type=='N'|trt_type=='P'|trt_type=='drought'|trt_type=='irr'|trt_type=='precip_vari', 'single_resource', ifelse(trt_type=='burn'|trt_type=='mow_clip'|trt_type=='herb_rem'|trt_type=='temp'|trt_type=='plant_mani', 'single_nonresource', ifelse(trt_type=='all_resource'|trt_type=='both', 'three_way', 'two_way'))))

#export, group by shape type, and paste lines below
# write.csv(chainsEquations,'stdtimebytrt_eH_equations_04092019.csv', row.names=F)








###percent change as richness metric, N(0,1) priors------------------------------------------
#raw chains data
memory.limit(size=50000)
chains1 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\PC_lnRR_all years\\PC-timestdbytrt_lnRR_0.csv', comment.char='#')
chains1 <- chains1[-1:-5000,]
chains2 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\PC_lnRR_all years\\PC-timestdbytrt_lnRR_1.csv', comment.char='#')
chains2 <- chains2[-1:-5000,]
chains3 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\PC_lnRR_all years\\PC-timestdbytrt_lnRR_2.csv', comment.char='#')
chains3 <- chains3[-1:-5000,]
chains4 <- read.csv('C:\\Users\\lapie\\Dropbox (Smithsonian)\\working groups\\CoRRE\\converge_diverge\\La Pierre_comm difference_final model results_01122018\\final models_all years_04082019\\PC_lnRR_all years\\PC-timestdbytrt_lnRR_3.csv', comment.char='#')
chains4 <- chains4[-1:-5000,]

chainsCommunity <- rbind(chains1, chains2, chains3, chains4)


#density plot of chains
plot(density(chainsCommunity$D.1.1.1))
plot(density(chainsCommunity$D.1.1.2))
plot(density(chainsCommunity$D.1.1.3))


#get values for overall (mean) lines across levels of plot mani
#mean change are the 1's, richness are the 2's
chainsCommunity2 <- chainsCommunity%>%
  select(lp__,
         #trt_type intercepts: center digit refers to trts
         E.1.1.1, E.2.1.1, E.1.2.1, E.2.2.1, E.1.3.1, E.2.3.1, E.1.4.1, E.2.4.1, E.1.5.1, E.2.5.1,
         E.1.6.1, E.2.6.1, E.1.7.1, E.2.7.1, E.1.8.1, E.2.8.1, E.1.9.1, E.2.9.1, E.1.10.1, E.2.10.1,
         E.1.11.1, E.2.11.1, E.1.12.1, E.2.12.1, E.1.13.1, E.2.13.1, E.1.14.1, E.2.14.1, E.1.15.1, E.2.15.1,
         E.1.16.1, E.2.16.1,
         #trt_type linear slopes: center digit refers to trts
         E.1.1.2, E.2.1.2, E.1.2.2, E.2.2.2, E.1.3.2, E.2.3.2, E.1.4.2, E.2.4.2, E.1.5.2, E.2.5.2,
         E.1.6.2, E.2.6.2, E.1.7.2, E.2.7.2, E.1.8.2, E.2.8.2, E.1.9.2, E.2.9.2, E.1.10.2, E.2.10.2,
         E.1.11.2, E.2.11.2, E.1.12.2, E.2.12.2, E.1.13.2, E.2.13.2, E.1.14.2, E.2.14.2, E.1.15.2, E.2.15.2,
         E.1.16.2, E.2.16.2,
         #trt_type quadratic slopes: center digit refers to trts and interactions with anpp and gamma diversity
         E.1.1.3, E.2.1.3, E.1.2.3, E.2.2.3, E.1.3.3, E.2.3.3, E.1.4.3, E.2.4.3, E.1.5.3, E.2.5.3,
         E.1.6.3, E.2.6.3, E.1.7.3, E.2.7.3, E.1.8.3, E.2.8.3, E.1.9.3, E.2.9.3, E.1.10.3, E.2.10.3,
         E.1.11.3, E.2.11.3, E.1.12.3, E.2.12.3, E.1.13.3, E.2.13.3, E.1.14.3, E.2.14.3, E.1.15.3, E.2.15.3,
         E.1.16.3, E.2.16.3,
         #ANPP intercept, linear, and quad slopes (center digit): 2=anpp
         D.1.2.1, D.2.2.1,
         D.1.2.2, D.2.2.2,
         D.1.2.3, D.2.2.3,
         #richness intercept, linear, and quad slopes (center digit): 3=gamma diversity
         D.1.3.1, D.2.3.1,
         D.1.3.2, D.2.3.2,
         D.1.3.3, D.2.3.3,
         #overall intercept, linear, and quad slopes (center digit): 1=overall
         D.1.1.1, D.2.1.1,
         D.1.1.2, D.2.1.2,
         D.1.1.3, D.2.1.3)%>%
  gather(key=parameter, value=value, E.1.1.1:D.2.1.3)%>%
  group_by(parameter)%>%
  summarise(median=median(value), sd=sd(value))%>%
  mutate(lower=median-2*sd, upper=median+2*sd, lower_sign=sign(lower), upper_sign=sign(upper), diff=lower_sign-upper_sign, median=ifelse(diff==-2, 0, median))

# write.csv(chainsCommunity2, 'stdtimebytrt_PC_summary_04092019.csv')


#gather the intercepts, linear slopes, and quadratic slopes for all treatments
#numbers are B.variable.number.parameter (e.g., B.mean.87.slope)
#variable (second place): 1=mean change, 2=richness change
#parameter (final digit): 1=intercept, 2=linear slope, 3=quad slope
#set any that are not significant (CI overlaps 0) as 0

#get mean parameter values across all runs for each experiment, treatment, etc
chainsFinalMean <- as.data.frame(colMeans(chainsCommunity[,8918:11545]))%>% #may need to delete original four chains dataframes to get this to work
  add_rownames('parameter')
names(chainsFinalMean)[names(chainsFinalMean) == 'colMeans(chainsCommunity[, 8918:11545])'] <- 'mean'
#get sd of parameter values across all runs for each experiment, treatment, etc
chainsFinalSD <- as.data.frame(colSd(chainsCommunity[,8918:11545]))
names(chainsFinalSD)[names(chainsFinalSD) == 'colSd(chainsCommunity[, 8918:11545])'] <- 'sd'

chainsFinal <- cbind(chainsFinalMean, chainsFinalSD)%>%
  #split names into parts
  separate(parameter, c('B', 'variable', 'id', 'parameter'))%>%
  select(-B)%>%
  #rename parts to be more clear
  mutate(variable=ifelse(variable==1, 'mean', 'richness'),
         parameter=ifelse(parameter==1, 'intercept', ifelse(parameter==2, 'linear', 'quadratic')),
         id=as.integer(id))%>%
  #if 95% confidence interval overlaps 0, then set mean to 0
  mutate(lower=mean-2*sd, upper=mean+2*sd, lower_sign=sign(lower), upper_sign=sign(upper), diff=lower_sign-upper_sign, mean=ifelse(diff==-2, 0, mean))%>%
  #spread by variable
  select(variable, id, parameter, mean)%>%
  spread(key=parameter, value=mean)

# write.csv(chainsFinal, 'stdtimebytrt_PC_means_04092019.csv')


#merge together with experiment list
trtID <- read.csv('bayesian_trt_index.csv')%>%
  select(site_code, project_name, community_type, treatment, treat_INT)%>%
  unique()%>%
  rename(id=treat_INT)
timeStd <- read.csv('bayesian_trt_index.csv')%>%
  group_by(comm_INT, treat_INT)%>%
  summarise(time_mean=mean(time), time_std=sd(time))%>%
  ungroup()%>%
  rename(id=treat_INT)
chainsExperiment <- chainsFinal%>%
  left_join(trtID)%>%
  left_join(trtInfo)%>%
  left_join(timeStd)

#generate equations for main figure of richness and compositional responses through time
chainsEquations <- chainsExperiment%>%
  #get standardized experiment length
  mutate(alt_length=experiment_length - min_year)%>%
  # mutate(alt_length=ifelse(alt_length>=20, 19, alt_length))%>%
  # mutate(color=ifelse(rrich<31, '#1104DC44', ifelse(rrich<51&rrich>30, '#4403AE55', ifelse(rrich<71&rrich>50, '#77038166', ifelse(rrich>70, '#DD032688', 'grey')))))%>%
  mutate(curve1='stat_function(fun=function(x){(',
         curve2=' + ',
         curve3='*((x-',
         curve4=')/',
         curve5=') + ',
         curve6='*((x-',
         curve7=')/',
         curve8=ifelse(variable=='mean', ')^2)*(0.1860342)+(0.3070874)}, size=2, xlim=c(0,',
                       ')^2)*(0.2458553)+(-0.06898448)}, size=2, xlim=c(0,'),
         curve9=')) +',
         curve=paste(curve1, intercept, curve2, linear, curve3, time_mean, curve4, time_std, curve5, quadratic, curve6, time_mean, curve7, time_std, curve8, alt_length, curve9, sep=''))
# mutate(trt_overall=ifelse(trt_type=='CO2'|trt_type=='N'|trt_type=='P'|trt_type=='drought'|trt_type=='irr'|trt_type=='precip_vari', 'single_resource', ifelse(trt_type=='burn'|trt_type=='mow_clip'|trt_type=='herb_rem'|trt_type=='temp'|trt_type=='plant_mani', 'single_nonresource', ifelse(trt_type=='all_resource'|trt_type=='both', 'three_way', 'two_way'))))

#export, group by shape type, and paste lines below
# write.csv(chainsEquations,'stdtimebytrt_PC_equations_04092019.csv', row.names=F)