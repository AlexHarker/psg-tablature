\version "2.24.1"

%% Create the basic tuning when no pedals or levers are engaged

 PSGE-tuning = \stringTuning <b, d e fis gis b e' gis' dis' fis'>
  
%% Create a set of pedals and levers with an ID (symbol, string or number) and a list of string alterations in semitones
  
pedalA = \psg-define-pedal-or-lever A #'(2 0 0 0 0 2 0 0 0 0)
pedalB = \psg-define-pedal-or-lever B #'(0 0 0 0 1 0 0 1 0 0)
pedalC = \psg-define-pedal-or-lever C #'(0 0 0 0 0 2 2 0 0 0)
pedalD = \psg-define-pedal-or-lever D #'(-2 0 0 0 -2 -2 0 0 0 0)
leverLKL = \psg-define-pedal-or-lever LKL #'(0 0 1 0 0 0 1 0 0 0) 
leverLKV = \psg-define-pedal-or-lever-stopped LKV #'(0 0 0 0 2 0 0 0 0 0) #'(0 0 0 0 3 0 0 0 0 0)
leverLKR = \psg-define-pedal-or-lever LKR #'(0 0 -1 0 0 0 -1 0 0 0)
leverRKL = \psg-define-pedal-or-lever RKL #'(0 0 0 2 0 0 0 0 1 2)
leverRKR = \psg-define-pedal-or-lever-stopped RKR #'(0 -2 0 0 0 0 0 0 -1 0) #'(0 -2 0 0 0 0 0 0 -2 0)

%% Define the copedent by passing the tuning and a list of pedals and levers

copedentE = \psg-define-copedent #PSGE-tuning #(list pedalA pedalB pedalC pedalD leverLKL leverLKV leverLKR leverRKL leverRKR)
