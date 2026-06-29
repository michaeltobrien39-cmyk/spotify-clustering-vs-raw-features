#---SETUP PACKAGES, THEME & SEED---
#Load Packages
library(tidyverse) 
library(cluster)      #For clustering, eg: silhouette
library(factoextra)   #For clustering, eg: fviz_nbclust, fviz_cluster
library(janitor)      #For tidy frequency tables, eg: tabyl
library(scales)       #For axis formating, eg: comma in plots
library(ggcorrplot)   #For correlations
library(party)        #For Decision Tree
library(randomForest) #For Random Forests
library(ggplot2)      #For Visualisations
library(patchwork)    #For Diagnostic Panel 
#Data import
music_tracks <- read_csv("dataset.csv")
#Set Theme & Colours
theme_report <- theme_minimal(base_size = 10)
grey_palette <- c("grey10", "grey20", "grey30", "grey40", "grey50", "grey60")
#Set Seed for the whole script - Reproducbility 
set.seed(123)
#---DATA IMPORT & INSPECTION---
#Import Data
music_tracks <- read_csv("dataset.csv")
#Structure checks 
view(music_tracks)
names(music_tracks)
dim(music_tracks)
str(music_tracks)
#Data Summary
summary(music_tracks)
#Missing values
sum(is.na(music_tracks))
colSums(is.na(music_tracks))
which(is.na(music_tracks$artists)) 
which(is.na(music_tracks$album_name))
which(is.na(music_tracks$track_name))
#Duplicates Check
sum(duplicated(music_tracks))
sum(duplicated(music_tracks$track_id))
#---DATA CLEANING---
#Remove Index Column - Just shows row number, could intefer with predictors 
music_tracks <- music_tracks %>% select(-`...1`)
glimpse(music_tracks)
#Remove Impossible Values
#eg:data can't have 0 duration & 0 bpm tempo would distort scaling/clustering
music_tracks <- music_tracks %>%
  filter(duration_ms > 0, tempo > 0)
#Clean Missing Values 
music_tracks <- music_tracks %>%
  drop_na(track_name, artists, album_name)
#Remove Duplicates
music_tracks <- music_tracks %>%
  distinct(track_id, .keep_all = TRUE)
nrow(music_tracks)
#Convert Explicit into a factor - For Tables/SPSS Conversion
music_tracks <- music_tracks %>%
  mutate(explicit = factor(explicit,
                           levels = c(FALSE, TRUE),
                           labels = c("Not explicit", "Explicit")))
#---DATA PREPERATION---
#Select Clustering Variable - Audio features only
#Key/Mode/Time signature removed as they are integers/categories
#Duration is excluded as it contains extreme outliers - will beused in SPSS 
cluster_variables <- music_tracks %>%
  select(danceability, energy, loudness, speechiness,
         acousticness, instrumentalness, liveness, valence, tempo)
#Create a correlation heatmap - investigates if there is high correlation, double-weightedness
correlation_cv <- round(cor(cluster_variables), 2)
ggcorrplot(correlation_cv,
           type   = "lower", #Easier to read than a table
           lab    = TRUE, #Show value 
           colors = c("grey90", "white", "grey10")) +
  labs(title = "Correlation of Audio Features",
       x = NULL, #easier to read without axis
       y = NULL) +
  theme_report
#Energy is highly correlated with loudness-removed so it is not double-weighted in the distanc
cluster_variables <- cluster_variables %>% select(-loudness)
#Scale Clustering Variables - mean 0, sd 1
#eg: Tempo is on a larger range than 0-1 features - distance would dominate
cluster_scaled <- scale(cluster_variables)
#---CHOOSING K NUMBER---
#Use a Sample - Silhouette + Elbow require full pairwise distance matrix
#But cluster_scaled reaches memoru limit, use a random sample but k-means will use full sample
sample_idx     <- sample(nrow(cluster_scaled), 5000)
cluster_sample <- cluster_scaled[sample_idx, ]
#Elbow Method
p_elbow <- fviz_nbclust(cluster_sample, kmeans, method = "wss", nstart = 25,
                        linecolor = "grey30") +
  labs(title = "(a)Elbow Method") +
  theme_report
#Average Silhouette
p_sil <- fviz_nbclust(cluster_sample, kmeans, method = "silhouette", nstart = 25,
                      linecolor = "grey30") +
  labs(title = "(b)Average Silhouette",
       x = "Number of clusters k",
       y = "Silhouette width") +
  
  theme_report
#Gap Statistic Method 
gap_stat <- clusGap(cluster_scaled[sample(nrow(cluster_scaled), 5000), ],
                    FUN = kmeans, nstart = 25, K.max = 8, B = 25)
p_gap <- fviz_gap_stat(gap_stat, 
                       linecolor = "grey30") +
  labs(title = "(c) Gap statistic",
       x = "Number of clusters k",
       y = "Gap Statistic")

#Create Diagnostic Panel for methods section
methods_panel <- p_elbow | p_sil | p_gap

methods_panel <- methods_panel+
  plot_annotation(
    title = "K-selection diagnostics (sample of 5,000 tracks)",
    theme = theme(plot.title = element_text(face = "bold"))
  )
methods_panel
#---RUN K-MEANS ON FULL DATA---
k_final <- 4 #Value based of elbow, sihouette and gap statistic  

km <- kmeans(cluster_scaled, centers = k_final, nstart = 25, iter.max = 50)

km$size #Cluster sizes
km$betweenss / km$totss  #Share of variance explained

# Cluster scatter on the first two principal components (sample, for
# legibility). Greyscale only.
fviz_cluster(list(data    = cluster_sample,
                  cluster = km$cluster[sample_idx]),
             geom    = "point",
             ellipse = TRUE,
             palette = grey_palette[1:k_final],
             ggtheme = theme_report) +
  labs(title = "K-means Clusters (Sample of 5,000)")

# Silhouette of the chosen solution (sample).
sil <- silhouette(km$cluster[sample_idx], dist(cluster_sample))
fviz_silhouette(sil, palette = grey_palette[1:k_final]) +
  labs(title = "Silhouette of Final Clusters (sample)") +
  theme_report

#Hierarchial Clustering - robustness check
hc.cut <- hcut(cluster_sample, k = 4, hc_method = "complete")  #using complete 
fviz_dend(hc.cut, show_labels = FALSE, rect = TRUE)  #shows cluster dendrogram

#---PROFILING CLUSTERS---
#Attach Clusters back to main dataset
music_tracks <- music_tracks %>%
  mutate(cluster = factor(km$cluster))

#Caluclate the Mean of each audio feature & mean popularity (for Multiple Regression) per cluster.
cluster_profile <- music_tracks %>%
  group_by(cluster) %>%
  summarise(
    n                = n(),
    popularity       = mean(popularity),
    danceability     = mean(danceability),
    energy           = mean(energy),
    speechiness      = mean(speechiness),
    acousticness     = mean(acousticness),
    instrumentalness = mean(instrumentalness),
    liveness         = mean(liveness),
    valence          = mean(valence),
    tempo            = mean(tempo)
  )
cluster_profile 

#Visualise and Standarsise the Clusters mean audio feautures - help justify names
profile_long <- cluster_profile %>%
  select(-n, -popularity) %>% #Remove columns not needed for the heatmap
  mutate(across(-cluster, ~ as.numeric(scale(.)))) %>%  #Z-score across clusters
  pivot_longer(-cluster, names_to = "feature", values_to = "z") #Change data into long fromat

profile_long <- profile_long %>%
  mutate(label_colour = ifelse(z > 0.5, "white", "black")) #Make labels white on darker tiles

ggplot(profile_long, aes(x = feature, y = cluster, fill = z)) +
  geom_tile(colour = "white") + #Add tiles with white boarders
  geom_text(aes(label = sprintf("%.1f", z), colour = label_colour)) + #Add number labels
  scale_fill_gradient(low = "white", high = "grey20", name = "z-score") + #Colour tiles white to dark grey, 
  scale_colour_identity() +
  labs(title = "Cluster Audio Profiles (standardised means)",
       x = "Audio feature", y = "Cluster", fill = "z-score") +
  theme_report +
  theme(axis.text.x = element_text(size = 14))


#Name the Clusters based of heatmap & table 
music_tracks <- music_tracks %>%
  mutate(cluster = factor(km$cluster,
                          levels = 1:4,
                          labels = c("Fast Intensity",
                                     "Upbeat Danceable",
                                     "Lively Speech Heavy",
                                     "Quiet Acoustic Instrumental")))

#Check the most common genres in each cluster profile
#Genres are not true labels 
top_genres_by_cluster <- music_tracks %>%
  count(cluster, track_genre, sort = TRUE) %>% #Count tracks per genre in each cluster
  group_by(cluster) %>% #keep rankings seperate for each cluster
  slice_max(order_by = n, n = 5) #keep top 5 genres in each cluster
top_genres_by_cluster


#Boxplot:Compare the distribution of track popularity across cluster 
ggplot(music_tracks, aes(x = cluster, y = popularity)) +
  geom_boxplot(fill = "grey80", outlier.alpha = 0.2) + #Use transparent outliers for readability 
  labs(title = "Track Popularity by Cluster",
       x = "Cluster", y = "Popularity (0-100)") +
  theme_report +
  theme(axis.text.x = element_text(size = 14))

#---EXPORT FILE FOR SPSS REGRESSION---
music_tracks_clustered <- music_tracks %>%
  select(track_id,            #Identifier 
         popularity,          #Regression target
         cluster,             #Engineered Predictor from clustering
         explicit,            #Additonal Predictor
         duration_ms,         #Additonal Predictor
         danceability, energy, loudness, speechiness, #Original audio feautres
         acousticness, instrumentalness, liveness, valence, tempo, 
         track_genre)         #Genre context for interpretgation

write_csv(music_tracks_clustered, "music_tracks_clustered.csv")


#---CLASSIFICATION WITH CLUSTER-BASED PREDICTORS---
#Create the modelling dataset - popualrity is seperated using the median so classes
#are roughly 50/50, easier to interpret
median_pop <- median(music_tracks$popularity)
median_pop

tree_data_clusters <- music_tracks %>%
  mutate(popular = factor(ifelse(popularity >= median_pop,
                                 "Popular", "Not Popular"),
                          levels = c("Not Popular", "Popular"))) %>%
  select(popular, cluster, explicit, duration_ms)

# Check the class balance is 50/50
table(tree_data_clusters$popular)
prop.table(table(tree_data_clusters$popular))

#Create Train/Test Split (80/20) 
ind_clusters <- sample(2,
                       nrow(tree_data_clusters),
                       replace = TRUE,prob = c(0.8, 0.2))
train_clusters <- tree_data_clusters[ind_clusters == 1, ]
test_clusters  <- tree_data_clusters[ind_clusters == 2, ]

nrow(train_clusters) 
nrow(test_clusters)

#---Decision Tree - With Clustered features---
tree_clusters <- ctree(popular ~ .,
                       data = train_clusters,
                       controls = ctree_control(mincriterion = 0.9999, #Forces high confidence at each split
                                                minsplit = 20))
print(tree_clusters)

#Visualisation
plot(tree_clusters)  #tree with bar plots at the leaves
plot(tree_clusters, type = "simple") #compact numeric version


#Train accuracy
pred_tree_c_train <- predict(tree_clusters, train_clusters)
conf_tree_c_train <- table(Predicted = pred_tree_c_train,
                           Actual    = train_clusters$popular)
conf_tree_c_train
acc_tree_c_train  <- sum(diag(conf_tree_c_train)) / sum(conf_tree_c_train)
acc_tree_c_train

#Test accuracy
pred_tree_c_test <- predict(tree_clusters, test_clusters)
conf_tree_c_test <- table(Predicted = pred_tree_c_test,
                          Actual    = test_clusters$popular)
conf_tree_c_test
acc_tree_c_test  <- sum(diag(conf_tree_c_test)) / sum(conf_tree_c_test)
acc_tree_c_test


#---Randon Forest - with Clustered features---
#Default ntree = 500 trees
rf_clusters <- randomForest(popular ~ ., data = train_clusters)
print(rf_clusters)
#Training confusion matrix
pred_rf_c_train <- predict(rf_clusters)
conf_rf_c_train <- table(Predicted = pred_rf_c_train,
                         Actual    = train_clusters$popular)
acc_rf_c_train  <- sum(diag(conf_rf_c_train)) / sum(conf_rf_c_train)
acc_rf_c_train

#Variable importance and forest diagnostics
importance(rf_clusters)
varImpPlot(rf_clusters,
           main = "Variable Importance - Cluster-Based RF")
hist(treesize(rf_clusters),
     main = "Tree sizes - Cluster-Based RF",
     xlab = "Nodes per tree")
plot(rf_clusters,
     main = "Error rate by number of trees - Cluster-Based RF")

#Test accuracy
pred_rf_c_test <- predict(rf_clusters, newdata = test_clusters)
conf_rf_c_test <- table(Predicted = pred_rf_c_test,
                        Actual    = test_clusters$popular)
conf_rf_c_test
acc_rf_c_test  <- sum(diag(conf_rf_c_test)) / sum(conf_rf_c_test)
acc_rf_c_test
#---CLASSIFICATION WITH AUDIO FEATURE PREDICTORS---
#Create the modelling dataset - using raw audio feautures rather than clusters
tree_data_features <- music_tracks %>%
  mutate(popular = factor(ifelse(popularity >= median_pop,
                                 "Popular", "Not Popular"),
                          levels = c("Not Popular", "Popular"))) %>%
  select(popular, explicit, duration_ms,
         danceability, energy,
         speechiness, acousticness, instrumentalness,
         liveness, valence, tempo)
#Check balance 50/50 
table(tree_data_features$popular)
prop.table(table(tree_data_features$popular))

#Create Train/Test Split (80/20) 
ind_features <- sample(2,nrow(tree_data_features),
                       replace = TRUE,prob = c(0.8, 0.2))
train_features <-tree_data_features[ind_features == 1, ]
test_features  <-tree_data_features[ind_features == 2, ]

nrow(train_features)
nrow(test_features)

#---Decison Tree with Features---
tree_features <- ctree(popular ~ .,
                       data = train_features,
                       controls = ctree_control(mincriterion = 0.9999,
                                                minsplit = 20))
print(tree_features)

#Visualisation
plot(tree_features)                     
plot(tree_features, type = "simple")

#Train accuracy 
pred_tree_f_train <- predict(tree_features, train_features)
conf_tree_f_train <- table(Predicted = pred_tree_f_train,
                           Actual    = train_features$popular)
conf_tree_f_train
acc_tree_f_train  <- sum(diag(conf_tree_f_train)) / sum(conf_tree_f_train)
acc_tree_f_train

#Test accuracy
pred_tree_f_test <- predict(tree_features, test_features)
conf_tree_f_test <- table(Predicted = pred_tree_f_test,
                          Actual    = test_features$popular)
conf_tree_f_test
acc_tree_f_test  <- sum(diag(conf_tree_f_test)) / sum(conf_tree_f_test)
acc_tree_f_test


#---Randon Forest - with raw audio features---
rf_feautures <- randomForest(popular ~ ., data = train_features) 
print(rf_feautures)

#Training accuracy
pred_rf_f_train <- predict(rf_feautures)
conf_rf_f_train <- table(Predicted = pred_rf_f_train,
                         Actual    = train_features$popular)
acc_rf_f_train  <- sum(diag(conf_rf_f_train)) / sum(conf_rf_f_train)
acc_rf_f_train

#Variable importance and forest diagnostics
importance(rf_feautures)
varImpPlot(rf_feautures,
           main = "Variable Importance - Feature-Based RF")
hist(treesize(rf_feautures),
     main = "Tree sizes - Feature-Based RF",
     xlab = "Nodes per tree")
plot(rf_feautures,
     main = "Error rate by number of trees - Feature-Based RF")

# Test accuracy 
pred_rf_f_test <- predict(rf_feautures, newdata = test_features)
conf_rf_f_test <- table(Predicted = pred_rf_f_test,
                        Actual    = test_features$popular)
conf_rf_f_test
acc_rf_f_test  <- sum(diag(conf_rf_f_test)) / sum(conf_rf_f_test)
acc_rf_f_test

#Assessing the Cardinality of Variables - may have effected feature importance
#Feature Importance order in the Cluster RF
length(unique(music_tracks_clustered$duration_ms))
length(unique(music_tracks_clustered$cluster))
length(unique(music_tracks_clustered$explicit))
#Feature Importance order in the Feature RF
length(unique(music_tracks$acousticness))
length(unique(music_tracks$duration_ms))
length(unique(music_tracks$speechiness))
length(unique(music_tracks$energy))
length(unique(music_tracks$danceability))
length(unique(music_tracks$valence))
length(unique(music_tracks$tempo))
length(unique(music_tracks$liveness))
length(unique(music_tracks$instrumentalness))
length(unique(music_tracks$explicit))      




