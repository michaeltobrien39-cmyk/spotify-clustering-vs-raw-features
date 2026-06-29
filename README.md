# spotify-clustering-vs-raw-features
Does clustering audio features improve Spotify popularity prediction? Testing cluster labels vs raw features with K-means, regression and random forests (R + SPSS)
Spotify Track Popularity — Does Clustering Audio Features Beat the Raw Features?

A feature-engineering experiment on ~90,000 Spotify tracks: does compressing audio features into a small set of cluster labels improve popularity prediction, or do the raw continuous features carry more signal? Tested with both a linear model (multiple regression, SPSS) and non-linear models (decision tree and random forest, R).

The honest headline. Clustering lost. Raw audio features beat the four-cluster labels in every model — Random Forest 70.0% vs 55.8%, decision tree 61.5% vs 53.9%, and in regression R² 0.027 vs 0.006 — with the cluster classifier barely clearing the 51% baseline. Compressing eight continuous features into four groups discards the granularity the models rely on. The wider lesson: clustering as feature engineering only helps when cluster membership encodes discrete latent structure the raw numbers blur, which Spotify audio does not.

Problem
Streaming platforms use audio features to shape playlist placement and recommendation, and labels use similar metrics for A&R decisions. That raises a practical question: can a track's commercial popularity be forecast from its acoustic attributes alone, and how should those features be represented for a model — as raw values, or as interpretable audio "types"? This project tests both, and compares linear against non-linear models.

Data
114,000 tracks raw, cleaned to 89,583 unique tracks (removed an index column, impossible values such as zero duration or tempo, an incomplete metadata row, and 24,259 duplicate track IDs — multi-genre repeats that would otherwise inflate the sample and bias the models).
Source: Spotify Tracks Dataset on Kaggle — [paste your Kaggle dataset URL]. Column descriptions are documented there; raw data is not redistributed here.
Clustering used 8 scaled audio features; loudness was dropped after a correlation check (r = 0.76 with energy) to avoid double-weighting the distance.

Tools
R (tidyverse, cluster, factoextra, party, randomForest) for cleaning, clustering and the tree and forest models; SPSS for the hierarchical multiple regression.

Approach
1. Cleaning and preparation. Deduplication on track ID, impossible-value removal, and scaling of the audio features.
2. Clustering. K-means with k = 4. The elbow, silhouette and gap-statistic diagnostics disagreed (silhouette peaked at k = 2, an ambiguous elbow, a rising gap statistic), so k = 4 was chosen for interpretable, actionable archetypes. Clusters were profiled and named from standardised feature means: Fast Intensity, Upbeat Danceable, Lively Speech-Heavy, and Quiet Acoustic-Instrumental, with a hierarchical-clustering robustness check.
3. Prediction, two feature sets compared. Each model was trained twice: once on the cluster label plus structural features (explicit, duration), and once on the raw audio features. Linear: a hierarchical multiple regression in SPSS (Block 1 structural baseline, Block 2 adding cluster dummies with the largest cluster as reference, then repeated with raw features). Non-linear: a decision tree and a random forest on a median split of popularity (Popular vs Not Popular, roughly 49/51), with an 80/20 train/test split.

Key findings
Raw features beat clusters in every model. Test accuracy — Random Forest: raw 70.0% vs cluster 55.8%; Decision Tree: raw 61.5% vs cluster 53.9%. The cluster classifier is barely above the 51% base rate.
The regression agreed. Cluster dummies lifted R² only to 0.006 (from a 0.003 baseline of duration and explicit), while raw audio features reached 0.027 — a 4.5x improvement over clusters, though both explain under 3% of popularity variance. The strongest raw effects were instrumentalness (B = −0.123), speechiness (−0.078) and danceability (+0.042).
The clusters were real but weak and unrelated to popularity. They explained about 37% of audio-feature variance with a low mean silhouette (~0.16), the smallest group (~8%) the weakest at 0.06. Genres mixed within clusters (drum-and-bass and heavy metal both land in the high-intensity group), so the boundaries are not natural — and mean popularity was near-identical across all four clusters (31 to 34 out of 100).
Even the raw-feature ceiling is modest (~70%): audio alone only partly explains popularity, consistent with the view that streaming success is shaped largely by factors outside the audio, such as artist reach, playlisting, marketing and release context.
A note on feature importance: duration has 50,626 unique values against 4 for the cluster label, and high-cardinality variables can inflate Gini importance. But tempo has similar cardinality yet ranks below several lower-cardinality audio features, which is evidence the feature model captures genuine signal rather than a cardinality artefact.

Why clustering didn't help (the core argument)
Clustering as feature engineering trades detail for compression: it replaces continuous features with a single categorical "type". That helps only when membership encodes discrete latent structure the raw features blur — distinct regimes a model cannot easily recover from the continuous values. Spotify audio has no such hidden grouping that predicts popularity, so the compression is pure information loss and the raw features win. The managerial read is that the archetypes are useful as a descriptive layer for audience segmentation and playlist storytelling, but they should not be the predictive input — that job belongs to the raw features in a flexible model.

Selected visuals
Popularity by cluster (boxplot) showing near-identical popularity across the four groups; model comparison (cluster-based vs raw-feature accuracy for the tree and forest); and the standardised cluster audio profiles.

What I'd do next
Add non-audio context — artist popularity, playlist placement, release recency and label — since audio alone caps the model at around 70% and under 3% of variance, so the real predictive power likely sits in these external signals.
Model popularity on its full 0 to 100 scale (or in several bands) rather than a median split, so the model uses the whole signal instead of a coarse binary.
Tune the non-linear models more thoroughly (gradient boosting, a deeper hyperparameter search) beyond the light mtry adjustment, to confirm the raw-feature ceiling.
Keep the clusters for what they are good at — a descriptive segmentation layer for playlisting and audience storytelling — rather than as predictive inputs.

Repository structure
spotify_audio_clustering.R   R: cleaning, clustering, decision tree, random forest
spss/                        SPSS multiple-regression output (and syntax if available)
figures/                     popularity-by-cluster, model comparison, cluster profiles
README.md                    this file

How to run
Open spotify_audio_clustering.R in RStudio and run top to bottom; packages load at the top and set.seed(123) makes results reproducible. Download the dataset from the Kaggle link above and place dataset.csv in the working directory. The multiple-regression arm was run separately in SPSS on the exported music_tracks_clustered.csv.
