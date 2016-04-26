class GRank
    def self.question_matrix
        {
            'new' => {
                'text' => 'I have never played Ultimate before',
                'questions' => {
                    'level_of_play' => {},
                    'athleticism' => {
                        'a' => {'score' => 0.0, 'text' => 'I have never played organized sports'},
                        'b' => {'score' => 1.0, 'text' => 'I played some high school sport(s)'},
                        'c' => {'score' => 2.0, 'text' => 'I played a college scholarship sport'}
                    },
                    'ultimate_skills' => {}
                }
            },
            'rec' => {
                'text' => 'Intramural, rec or church league, pickup, PE class, of military PT',
                'questions' => {
                    'level_of_play' => {},
                    'athleticism' => {
                        'a' => {'score' => 0.0, 'text' => 'Athleticism is not one of my strengths'},
                        'b' => {'score' => 1.0, 'text' => 'I can keep up with most the people in pickup games'},
                        'c' => {'score' => 2.0, 'text' => 'Very few pickup players can keep up with me on offense or defense'}
                    },
                    'ultimate_skills' => {
                        'a' => {'score' => 0.0, 'text' => 'I just play for exercise and I don\'t worry about the rules'},
                        'b' => {'score' => 0.5, 'text' => 'I\'m learning how to cut, throw, and play defense'},
                        'c' => {'score' => 1.0, 'text' => 'I have decent skills but I am just learning about stacks offenses, marking with a force, and defending on the force side'},
                        'd' => {'score' => 2.0, 'text' => 'I have decent skills and I understand both structured offense and defense'}
                    }
                }
            },
            'hs' => {
                'text' => 'Organized High School team (i.e. your team has a coach and practices)',
                'questions' => {
                    'level_of_play' => {
                        'a' => {'score' => 2.0, 'text' => 'I was selected to the U20 National team or was a candidate'},
                        'b' => {'score' => 1.5, 'text' => 'I was selected to my region/state\'s YCC team or equivalent'},
                        'c' => {'score' => 0.5, 'text' => 'I played on a varsity high school team (Paideia, Woodward, etc.)'},
                        'd' => {'score' => 0.5, 'text' => 'I played on a team with a coach (other GHSU team)'},
                        'e' => {'score' => 0.0, 'text' => 'Gym Class'},
                        'f' => {'score' => 0.0, 'text' => 'None of the above'}
                    },
                    'athleticism' => {
                        'a' => {'score' => 0.0, 'text' => 'Athleticism is not one of my strengths'},
                        'b' => {'score' => 1.0, 'text' => 'Average high school athlete'},
                        'c' => {'score' => 2.0, 'text' => 'Above Average High School Athlete'}
                    },
                    'ultimate_skills' => {
                        'a' => {'score' => 0.0, 'text' => 'I\'m just learning how to cut, throw, and play defense'},
                        'b' => {'score' => 1.0, 'text' => 'Decent at both offense and defense, but I\'m still learning and improving'},
                        'c' => {'score' => 2.0, 'text' => 'I\'m strong at both offense and defense'},
                        'd' => {'score' => 2.0, 'text' => 'I am an elite high school player on offense and defense'}
                    }
                }
            },
            'afdc' => {
                'text' => 'AFDC League or equivalent',
                'questions' => {
                    'level_of_play' => {},
                    'athleticism' => {
                        'a' => {'score' => 1.0, 'text' => 'Athleticism is not one of my strengths'},
                        'b' => {'score' => 2.0, 'text' => 'Exclude club and college players in the league, I am an average league athlete'},
                        'c' => {'score' => 3.0, 'text' => 'Exclude club and college players in the league, I am an above average league athlete'}
                    },
                    'ultimate_skills' => {
                        'a' => {'score' => 0.0, 'text' => 'I\'m just learning how to cut, throw, and play defense'},
                        'b' => {'score' => 1.0, 'text' => 'My skills are improving but I am still learning about stack offense, marking with a force, and defending on the force side'},
                        'c' => {'score' => 2.0, 'text' => 'I have decent skills and I understand both structured offense and defense'},
                        'd' => {'score' => 2.5, 'text' => 'Exclude club and college players in the league, I am GOOD at both offense and defense'},
                        'e' => {'score' => 3.0, 'text' => 'Exclude club and college players in the league, I am VERY GOOD at both. I could play club or I have played club in the past'}
                    }
                }
            },
            'college' => {
                'text' => 'USAU registered College ultimate',
                'questions' => {
                    'level_of_play' => {
                        'a' => {'score' => 1.5, 'text' => 'I played a considerable amount on a college nationals team, for a pro team, or was selected for a college allstar game'},
                        'b' => {'score' => 1.0, 'text' => 'I played at college regionals'},
                        'c' => {'score' => 0.0, 'text' => 'None of the above'}
                    },
                    'athleticism' => {
                        'a' => {'score' => 1.0, 'text' => 'Athleticism is not one of my strengths'},
                        'b' => {'score' => 2.0, 'text' => 'Average college athlete'},
                        'c' => {'score' => 3.0, 'text' => 'Above average college athlete'},
                        'd' => {'score' => 4.0, 'text' => 'Elite college athlete'}
                    },
                    'ultimate_skills' => {
                        'a' => {'score' => 1.0, 'text' => 'Still developing both offensive and defensive skills'},
                        'b' => {'score' => 2.0, 'text' => 'I mostly play defense. On offense I am a cutter and I am comfortable only throwing to open receivers'},
                        'c' => {'score' => 2.0, 'text' => 'Confident thrower/handler but I\'m not suited for person defense'},
                        'd' => {'score' => 2.5, 'text' => 'Decent at both offense and defense'},
                        'e' => {'score' => 3.0, 'text' => 'Decent at offense but I excel ("specialize") as a defensive player'},
                        'f' => {'score' => 3.0, 'text' => 'Decent at  defense but I excel ("specialize") as an offensive player'},
                        'g' => {'score' => 3.5, 'text' => 'Strong at both offense and defense'},
                        'h' => {'score' => 4.0, 'text' => 'Elite at a college level at both offense and defense'}
                    }
                }
            },
            'masters' => {
                'text' => 'Masters or grand masters club ultimate',
                'questions' => {
                    'level_of_play' => {
                        'a' => {'score' => 0.0, 'text' => 'I never played in the club series'},
                        'b' => {'score' => 0.5, 'text' => 'I played at grand masters nationals'},
                        'c' => {'score' => 0.5, 'text' => 'I played at masters regionals'},
                        'd' => {'score' => 1.0, 'text' => 'I played on a masters nationals team'}
                    },
                    'athleticism' => {
                        'a' => {'score' => 2.0, 'text' => 'Athleticism is not one of my strengths'},
                        'b' => {'score' => 2.5, 'text' => 'Average masters athlete'},
                        'c' => {'score' => 3.0, 'text' => 'Above average masters athlete '},
                        'd' => {'score' => 3.5, 'text' => 'Elite masters athlete'}
                    },
                    'ultimate_skills' => {
                        'a' => {'score' => 1.5, 'text' => 'I mostly play defense. On offense I am a cutter and I am comfortable only throwing to open receivers'},
                        'b' => {'score' => 1.5, 'text' => 'Confident thrower/handler but I\'m not suited for person defense'},
                        'c' => {'score' => 2.0, 'text' => 'Decent at both offense and defense'},
                        'd' => {'score' => 2.0, 'text' => 'Decent at offense but I excel ("specialize"} as a defensive player'},
                        'e' => {'score' => 2.0, 'text' => 'Decent at  defense but I excel ("specialize"} as an offensive player'},
                        'f' => {'score' => 2.5, 'text' => 'Strong at both offense and defense'},
                        'g' => {'score' => 3.0, 'text' => 'Elite at a masters level at both offense and defense'},
                    }
                }
            },
            'club' => {
                'text' => 'USAU registered Club ultimate',
                'questions' => {
                    'level_of_play' => {
                        'a' => {'score' => 0.0, 'text' => 'I have never played in the club series'},
                        'b' => {'score' => 0.0, 'text' => 'I have played at club SECTIONALS'},
                        'c' => {'score' => 0.5, 'text' => 'I have played at club REGIONALS, but didn\'t have a shot at making nationals'},
                        'd' => {'score' => 1.0, 'text' => 'I was on a team while it was a nationals contender'},
                        'e' => {'score' => 1.5, 'text' => 'I was on a team that made it to nationals but I didn\'t play a lot'},
                        'f' => {'score' => 2.0, 'text' => 'I played a considerable amount on a team at club nationals, worlds, or a pro team'}
                    },
                    'athleticism' => {
                        'a' => {'score' => 3.0, 'text' => 'Average club athlete'},
                        'b' => {'score' => 3.5, 'text' => 'Above average athlete club athlete'},
                        'c' => {'score' => 4.0, 'text' => 'Elite club athlete'}
                    },
                    'ultimate_skills' => {
                        'a' => {'score' => 1.5, 'text' => 'I mostly play defense. On offense I am a cutter and I am comfortable only throwing to open receivers'},
                        'b' => {'score' => 1.5, 'text' => 'Confident thrower/handler but I\'m not suited for person defense'},
                        'c' => {'score' => 2.0, 'text' => 'Decent at both offense and defense'},
                        'd' => {'score' => 2.0, 'text' => 'Decent at offense but I excel ("specialize"} as a defensive player'},
                        'e' => {'score' => 2.0, 'text' => 'Decent at defense but I excel ("specialize"} as an offensive player'},
                        'f' => {'score' => 2.5, 'text' => 'Strong at both offense and defense'},
                        'g' => {'score' => 3.0, 'text' => 'Elite at a club level at both offense and defense'}
                    }
                }
            }
        }
    end

    def self.calculate_score(answers)
        running_total = 0

        # Make sure we know what survey the person took
        matrix = self.question_matrix
        unless answers['experience'] && matrix.has_key?(answers['experience'])
            raise ArgumentError.new 'Malformed survey data. Please try again. (experience missing)'
        end

        # Make sure all required answers were submitted and filter out any extras; validate answers
        question_list = matrix[answers['experience']]['questions']
        question_list.keys.each do |cat|
            if question_list[cat].empty?
                answers.delete(cat)
                next
            end

            unless question_list[cat].has_key?(answers[cat])
                raise ArgumentError.new "Malformed survey data. Please try again. (#{cat} missing)"
            end

            running_total += question_list[cat][answers[cat]]['score']
        end

        running_total
    end

    def self.convert_answers_to_text(coded_answers)
        return {} if coded_answers.empty?

        relevant_matrix = self.question_matrix[coded_answers['experience']]

        text_answers = {}
        text_answers['Experience'] = relevant_matrix['text']

        %w(level_of_play ultimate_skills athleticism).each do |category|
            if coded_answers[category]
                text_answers[category.humanize] = relevant_matrix['questions'][category][coded_answers[category]]['text']
            end
        end
        return text_answers
    end
end
