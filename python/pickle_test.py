import pickle

infile = open("/Volumes/Work/Projects/lightfield/data/set2/features/frame0012.jpg.pkl", 'rb') 

base_descs = pickle.load(infile)
print base_descs

