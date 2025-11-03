VALID_BODY_MOCK =
  {
    "response" => {
      "creditVendResp" => {
        "clientID" => {
          "@attributes" => {
            "ean" => "VUPSB",
          },
        },
        "serverID" => {
          "@attributes" => {
            "id" => "1",
          },
        },
        "terminalID" => {
          "@attributes" => {
            "ean" => "0000000000002",
          },
        },
        "reqMsgID" => {
          "@attributes" => {
            "dateTime" => "20240403123920",
            "uniqueNumber" => "1230000001",
          },
        },
        "respDateTime" => "2024-05-13T08:20:47.1317707-04:00",
        "dispHeader" => "Credit Purchase",
        "operatorMsg" => "Credit Purchase Successful",
        "custMsg" => "Credit Purchase",
        "utility" => {
          "@attributes" => {
            "name" => "Aqualectra",
            "address" => "Durban",
            "taxRef" => "0",
          },
        },
        "clientStatus" => {
          "availCredit" => {
            "@attributes" => {
              "value" => "0",
              "symbol" => "XCG",
            },
          },
          "batchStatus" => {
            "@attributes" => {
              "banking" => "open",
              "sales" => "open",
              "shift" => "open",
            },
          },
        },
        "vendor" => {},
        "custVendDetail" => {
          "@attributes" => {
            "name" => "AGHA LIMITED",
            "address" => "Physical, ROSENDAAL, 121 I",
            "contactNo" => "123-abc-456",
            "accNo" => "3101149376",
            "locRef" => "4101162922",
            "utilityType" => "Electricity",
            "daysLastPurchase" => "0",
          },
        },
        "creditVendReceipt" => {
          "@attributes" => {
            "receiptNo" => "10071872",
          },
          "transactions" => {
            "tx" => [
              {
                "@attributes" => {
                  "receiptNo" => "10071872",
                },
                "amt" => {
                  "@attributes" => {
                    "value" => "100",
                    "symbol" => "XCG",
                  },
                },
                "creditTokenIssue" => {
                  "q1desc" => "Credit Token",
                  "q1meterDetail" => {
                    "@attributes" => {
                      "unitOfMeasurement" => "kWh",
                      "ti" => "1",
                      "msno" => "04257670895",
                      "sgc" => "300601",
                      "krn" => "1",
                    },
                    "q1meterType" => {
                      "@attributes" => {
                        "tt" => "02",
                      },
                    },
                  },
                  "q1token" => {
                    "q1stsCipher" => "04257670895000001327",
                  },
                  "q1units" => {
                    "@attributes" => {
                      "value" => "132.7",
                      "siUnit" => "kWh",
                    },
                  },
                  "q1resource" => {},
                },
                "tariff" => {
                  "name" => "DOMESTIC ELECTRICITY",
                  "desc" => "DOMESTIC ELECTRICITY",
                },
                "tariffBreakdown" => {
                  "q2steps" => {
                    "q2Step" => [
                      {
                        "q2units" => {
                          "@attributes" => {
                            "value" => "0",
                            "siUnit" => "kWh",
                          },
                        },
                        "q2rate" => {
                          "@attributes" => {
                            "value" => "0.60350",
                            "symbol" => "XCG",
                          },
                        },
                      },
                      {
                        "q2units" => {
                          "@attributes" => {
                            "value" => "0",
                            "siUnit" => "kWh",
                          },
                        },
                        "q2rate" => {
                          "@attributes" => {
                            "value" => "0.70980",
                            "symbol" => "XCG",
                          },
                        },
                      },
                      {
                        "q2units" => {
                          "@attributes" => {
                            "value" => "132.7",
                            "siUnit" => "kWh",
                          },
                        },
                        "q2rate" => {
                          "@attributes" => {
                            "value" => "0.75400",
                            "symbol" => "XCG",
                          },
                        },
                      },
                    ],
                  },
                },
              },
              {
                "amt" => {
                  "@attributes" => {
                    "value" => "0",
                    "symbol" => "XCG",
                  },
                },
                "accDesc" => "VAT",
              },
            ],
            "tenderAmt" => {
              "@attributes" => {
                "value" => "100",
                "symbol" => "XCG",
              },
            },
            "change" => {
              "@attributes" => {
                "value" => "0",
                "symbol" => "XCG",
              },
            },
          },
          "MonthlyTotals" => {},
        },
      },
    },
  }

VALID_BODY_MOCK_WITH_THREE_T0KENS = {
  "creditVendResp" => {
    "vendor" => {},
    "custMsg" => "Credit Purchase",
    "utility" => {
      "@attributes" => {
        "name" => "Aqualectra",
        "taxRef" => "0",
        "address" => "Durban",
      },
    },
    "clientID" => {
      "@attributes" => {
        "ean" => "VUPSB",
      },
    },
    "reqMsgID" => {
      "@attributes" => {
        "dateTime" => "20240524110249",
        "uniqueNumber" => "213",
      },
    },
    "serverID" => {
      "@attributes" => {
        "id" => "1",
      },
    },
    "dispHeader" => "Credit Purchase",
    "terminalID" => {
      "@attributes" => {
        "ean" => "0000000000002",
      },
    },
    "operatorMsg" => "Credit Purchase Successful",
    "clientStatus" => {
      "availCredit" => {
        "@attributes" => {
          "value" => "0",
          "symbol" => "XCG",
        },
      },
      "batchStatus" => {
        "@attributes" => {
          "sales" => "open",
          "shift" => "open",
          "banking" => "open",
        },
      },
    },
    "respDateTime" => "2024-05-24T10:59:55.4214831-04:00",
    "custVendDetail" => {
      "@attributes" => {
        "name" => "     Aida Josephina",
        "accNo" => "11877834",
        "locRef" => "3910894",
        "address" => "Physical, Montanja Di Rey 483B, Willemstad",
        "contactNo" => "",
        "utilityType" => "Electricity",
        "daysLastPurchase" => "479",
      },
    },
    "creditVendReceipt" => {
      "@attributes" => {
        "receiptNo" => "10071936",
      },
      "transactions" => {
        "tx" => [
          {
            "creditTokenIssue" => {
              "q1desc" => "KeyChange Token1",
              "q1token" => {
                "q1stsCipher" => "01300601011105956754",
              },
              "q1units" => {
                "@attributes" => {
                  "value" => "0",
                  "siUnit" => "kWh",
                },
              },
              "q1resource" => {},
              "q1meterDetail" => {
                "@attributes" => {
                  "ti" => "1",
                  "krn" => "1",
                  "sgc" => "300601",
                  "msno" => "04203136231",
                  "ctRatio" => "",
                  "ptRatio" => "",
                },
                "q1meterType" => {
                  "@attributes" => {
                    "tt" => "02",
                  },
                },
              },
            },
          },
          {
            "creditTokenIssue" => {
              "q2desc" => "KeyChange Token2",
              "q2token" => {
                "q2stsCipher" => "02300601012105956754",
              },
              "q2units" => {
                "@attributes" => {
                  "value" => "0",
                  "siUnit" => "kWh",
                },
              },
              "q2resource" => {},
              "q2meterDetail" => {
                "@attributes" => {
                  "ti" => "1",
                  "krn" => "1",
                  "sgc" => "300601",
                  "msno" => "04203136231",
                  "ctRatio" => "",
                  "ptRatio" => "",
                },
                "q2meterType" => {
                  "@attributes" => {
                    "tt" => "02",
                  },
                },
              },
            },
          },
          {
            "amt" => {
              "@attributes" => {
                "value" => "16",
                "symbol" => "XCG",
              },
            },
            "tariff" => {
              "desc" => "DOMESTIC ELECTRICITY",
              "name" => "DOMESTIC ELECTRICITY",
            },
            "@attributes" => {
              "receiptNo" => "10071936",
            },
            "tariffBreakdown" => {
              "q4steps" => {
                "q4Step" => [
                  {
                    "q4rate" => {
                      "@attributes" => {
                        "value" => "0.60350",
                        "symbol" => "XCG",
                      },
                    },
                    "q4units" => {
                      "@attributes" => {
                        "value" => "26.6",
                        "siUnit" => "kWh",
                      },
                    },
                  },
                  {
                    "q4rate" => {
                      "@attributes" => {
                        "value" => "0.70980",
                        "symbol" => "XCG",
                      },
                    },
                    "q4units" => {
                      "@attributes" => {
                        "value" => "0",
                        "siUnit" => "kWh",
                      },
                    },
                  },
                  {
                    "q4rate" => {
                      "@attributes" => {
                        "value" => "0.75400",
                        "symbol" => "XCG",
                      },
                    },
                    "q4units" => {
                      "@attributes" => {
                        "value" => "0",
                        "siUnit" => "kWh",
                      },
                    },
                  },
                ],
              },
            },
            "creditTokenIssue" => {
              "q3desc" => "Credit Token",
              "q3token" => {
                "q3stsCipher" => "04203136231000000266",
              },
              "q3units" => {
                "@attributes" => {
                  "value" => "26.6",
                  "siUnit" => "kWh",
                },
              },
              "q3resource" => {},
              "q3meterDetail" => {
                "@attributes" => {
                  "ti" => "1",
                  "krn" => "2",
                  "sgc" => "300601",
                  "msno" => "04203136231",
                  "unitOfMeasurement" => "kWh",
                },
                "q3meterType" => {
                  "@attributes" => {
                    "tt" => "02",
                  },
                },
              },
            },
          },
          {
            "amt" => {
              "@attributes" => {
                "value" => "0",
                "symbol" => "XCG",
              },
            },
            "accDesc" => "VAT",
          },
        ],
        "change" => {
          "@attributes" => {
            "value" => "0",
            "symbol" => "XCG",
          },
        },
        "tenderAmt" => {
          "@attributes" => {
            "value" => "16",
            "symbol" => "XCG",
          },
        },
      },
      "MonthlyTotals" => {},
    },
  },
}

# puts JSON.pretty_generate(SSS)
