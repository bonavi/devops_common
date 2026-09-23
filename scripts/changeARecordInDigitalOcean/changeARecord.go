package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
)

type DomainRecord struct {
	ID   int    `json:"id"`
	Type string `json:"type"`
	Name string `json:"name"`
	Data string `json:"data"`
}

type DomainRecordsResponse struct {
	DomainRecords []DomainRecord `json:"domain_records"`
}

type RecordSpec struct {
	Name string
	Type string // "A" or "CNAME"
	Data string
}

func main() {
	domain := "digitalsecurity001.ru" // <-- поменяй домен здесь
	apiToken := ""

	records := []RecordSpec{
		// Green nodes — A records
		{Name: "admin", Type: "A", Data: "185.5.55.23"},
		{Name: "m-admin", Type: "A", Data: "111.88.255.245"},

		// Blue nodes → m-admin (CNAME)
		{Name: "web", Type: "CNAME", Data: "m-admin." + domain + "."},
		{Name: "grpc", Type: "CNAME", Data: "m-admin." + domain + "."},
		{Name: "rest", Type: "CNAME", Data: "m-admin." + domain + "."},
		{Name: "web.dev", Type: "CNAME", Data: "m-admin." + domain + "."},
		{Name: "grpc.dev", Type: "CNAME", Data: "m-admin." + domain + "."},
		{Name: "rest.dev", Type: "CNAME", Data: "m-admin." + domain + "."},

		// Blue nodes → admin (CNAME)
		{Name: "f-web", Type: "CNAME", Data: "admin." + domain + "."},
		{Name: "f-grpc", Type: "CNAME", Data: "admin." + domain + "."},
		{Name: "f-rest", Type: "CNAME", Data: "admin." + domain + "."},
		{Name: "f-web.dev", Type: "CNAME", Data: "admin." + domain + "."},
		{Name: "f-grpc.dev", Type: "CNAME", Data: "admin." + domain + "."},
		{Name: "f-rest.dev", Type: "CNAME", Data: "admin." + domain + "."},
	}

	existing, err := getAllRecords(domain, apiToken)
	if err != nil {
		fmt.Println("Error fetching records:", err)
		return
	}

	index := map[string]DomainRecord{}
	for _, r := range existing {
		index[r.Type+":"+r.Name] = r
	}

	for _, spec := range records {
		key := spec.Type + ":" + spec.Name
		if rec, found := index[key]; found {
			fmt.Printf("Updating %s %s -> %s\n", spec.Type, spec.Name, spec.Data)
			if err := upsertRecord(domain, apiToken, "PUT", rec.ID, spec); err != nil {
				fmt.Println("  Error:", err)
			}
		} else {
			fmt.Printf("Creating %s %s -> %s\n", spec.Type, spec.Name, spec.Data)
			if err := upsertRecord(domain, apiToken, "POST", 0, spec); err != nil {
				fmt.Println("  Error:", err)
			}
		}
	}

	fmt.Println("Done!")
}

func getAllRecords(domain, token string) ([]DomainRecord, error) {
	url := fmt.Sprintf("https://api.digitalocean.com/v2/domains/%s/records?per_page=200", domain)
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Add("Authorization", "Bearer "+token)
	req.Header.Add("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, _ := ioutil.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("API error: %s", string(body))
	}

	var result DomainRecordsResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}
	return result.DomainRecords, nil
}

func upsertRecord(domain, token, method string, id int, spec RecordSpec) error {
	var url string
	if method == "PUT" {
		url = fmt.Sprintf("https://api.digitalocean.com/v2/domains/%s/records/%d", domain, id)
	} else {
		url = fmt.Sprintf("https://api.digitalocean.com/v2/domains/%s/records", domain)
	}

	payload := map[string]string{"type": spec.Type, "name": spec.Name, "data": spec.Data}
	jsonData, _ := json.Marshal(payload)

	req, _ := http.NewRequest(method, url, bytes.NewBuffer(jsonData))
	req.Header.Add("Authorization", "Bearer "+token)
	req.Header.Add("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 && resp.StatusCode != 201 {
		body, _ := ioutil.ReadAll(resp.Body)
		return fmt.Errorf("API error %d: %s", resp.StatusCode, string(body))
	}
	return nil
}
