//------------------------------------------------------------------------------
// Dijkstra on PyCoRAM (Software)
// Copyright (C) 2013, Shinya Takamaeda-Yamazaki
// License: Apache 2.0
//------------------------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>

typedef unsigned int Uint;
#include "heap.h"

//#define __STATIC__

#define MAX_NODES (32 * 1024 * 1024)
#define MAX_PAGES (16 * 1024 * 1024)
#define PAGE_SIZE (32)

#define HASHTABLE_SIZE (MAX_NODES)
#define HASH(__id__) (__id__ % HASHTABLE_SIZE)

#define MAX_INT (0xffffffff)

//------------------------------------------------------------------------------
typedef struct node Node;
typedef struct page Page;
typedef struct edge Edge;

struct node
{
  Uint id; // R
  Uint current_cost; // R/W
  Uint visited; // R/W
  Node* parent_node; // W
  Page* next_node_page_chain; // R (only for )
  Node* hash_chain; // R (only for node serach)
};

struct edge
{
  Node* next_node; // R
  Uint cost; // R
};

struct page
{
  Uint num_entries; // R
  Page* next_page; // R
  Edge edges [PAGE_SIZE]; // R 
};

//------------------------------------------------------------------------------
Uint number_of_nodes;
Uint number_of_edges;

#ifdef __STATIC__
Node node_array [MAX_NODES];
Page page_array [MAX_PAGES];
Node* hashtable [HASHTABLE_SIZE]; // to search a node
#else
Node* node_array;
Page* page_array;
Node** hashtable; // to search a node
#endif

PriorityQueue pqueue;

Uint node_index; // for node count
Uint page_index; // for edge count

//------------------------------------------------------------------------------
Node* add_node(Uint id)
{
  Node* p;
  p = hashtable[HASH(id)];

  if(p == NULL){ // new entry for hashtable
    hashtable[HASH(id)] = &node_array[node_index];
    node_index++;
    hashtable[HASH(id)]->id = id;
    hashtable[HASH(id)]->parent_node = NULL;
    hashtable[HASH(id)]->current_cost = MAX_INT;
    hashtable[HASH(id)]->visited = 0;
    hashtable[HASH(id)]->next_node_page_chain = NULL;
    hashtable[HASH(id)]->hash_chain = NULL;
    return hashtable[HASH(id)];
  }

  while(1){ // concat with existing entries
    if(p->id == id){
      return p; // already exists
    }
    if(p->hash_chain == NULL){ // tail
      p->hash_chain = &node_array[node_index];
      node_index++;
      p->hash_chain->id = id;
      p->hash_chain->parent_node = NULL;
      p->hash_chain->current_cost = MAX_INT;
      p->hash_chain->visited = 0;
      p->hash_chain->next_node_page_chain = NULL;
      p->hash_chain->hash_chain = NULL;
      return p->hash_chain;
    }
    p = p->hash_chain;
  }

  return NULL;
}

//------------------------------------------------------------------------------
void add_edge(Uint from, Uint to, Uint cost)
{
  Node* f = add_node(from);
  Node* t = add_node(to);

  if(f->next_node_page_chain == NULL){
    // New page
    f->next_node_page_chain = &page_array[page_index];
    page_index++;

    f->next_node_page_chain->next_page = NULL;
    f->next_node_page_chain->num_entries = 0;
  }

  Page* p = f->next_node_page_chain;
  while(p->next_page != NULL){
    p = p->next_page;
  }
  
  if(p->num_entries < PAGE_SIZE){
    p->edges[p->num_entries].next_node = t;
    p->edges[p->num_entries].cost = cost;
    p->num_entries++;
  }else{
    // New page
    p->next_page = &page_array[page_index];
    page_index++;

    p->next_page->next_page = NULL;
    p->next_page->num_entries = 0;

    p = p->next_page;
    p->edges[p->num_entries].next_node = t;
    p->edges[p->num_entries].cost = cost;
    p->num_entries++;
  }
}

//------------------------------------------------------------------------------
Node* get_node(Uint id)
{
  Node* p;
  p = hashtable[HASH(id)];
  while(p != NULL){
    if(p->id == id) return p;
    p = p->hash_chain;
  }
  return NULL; // not found
}

//------------------------------------------------------------------------------
void add_frontier(Uint id, Uint cost)
{
  Heapelement he;
  he.value = cost;
  he.id = id;
  enqueue(he, &pqueue);
}

//------------------------------------------------------------------------------
void update_frontiers(Node* current_node)
{
  Uint current_cost = current_node->current_cost;
  Page* page = current_node->next_node_page_chain;

  while(page != NULL){
    Uint num_next = page->num_entries;
    Uint i;

    for(i=0; i<num_next; i++){
      //printf("page[%d]\n", i);
      Uint cost = page->edges[i].cost;
      Node* next_node = page->edges[i].next_node;
      Uint new_cost = current_cost + cost;
      if((!next_node->visited) && (next_node->current_cost > current_cost + cost)){
        //printf("add node:%d cost:%d\n", next_node->id, new_cost);
        add_frontier(next_node->id, new_cost);
        next_node->current_cost = new_cost;
        next_node->parent_node = current_node;
      }
    }
    
    page = page->next_page;
  }
}

//------------------------------------------------------------------------------
int is_frontier_empty()
{
  return is_empty(&pqueue);
}

//------------------------------------------------------------------------------
Node* select_frontier()
{
  //printf("current size=%d\n", pqueue.size);
  Heapelement he = dequeue(&pqueue);
  Node* n = get_node(he.id);
  return n;
}

//------------------------------------------------------------------------------
Uint find_shortest_path(Uint start, Uint goal)
{
  Node* current_node = get_node(start);
  current_node->current_cost = 0;
  add_frontier(start, 0);

  while(current_node->id != goal){
    if(is_frontier_empty()) return MAX_INT;
    current_node = select_frontier();
    if(current_node->visited) continue;
    current_node->visited = 1;
    //printf("current_node=%d current_cost=%d\n", current_node->id, current_node->current_cost);
    update_frontiers(current_node);
  }

  return current_node->current_cost;
}

//------------------------------------------------------------------------------
void walk_result(Uint sum_of_cost, Uint start, Uint goal)
{
  Node* c = get_node(goal);
  printf("route: ");

  while(c != NULL){
    //printf("%d, ", c->id);
    printf("%d %d\n", c->id, c->current_cost);
    if(c->id == start) break;
    c = c->parent_node;
  }
  
  printf("\r\n");
  printf("cost: %d", sum_of_cost);
  printf("\r\n");
}

//------------------------------------------------------------------------------
int main(int argc, char** argv)
{

  FILE* fp = fopen(argv[3], "r");
  if(fp == NULL){
    printf("no such file\n");
    return -1;
  }

  Uint start = atoi(argv[1]);
  Uint goal = atoi(argv[2]);

  /*
  Uint start, goal;
  if(fscanf(stdin, "%d %d\n", &start, &goal) != 2){
    exit(-1);    
  }
  */

  if(fscanf(fp, "%d %d\n", &number_of_nodes, &number_of_edges) != 2){
    exit(-1);
  }

  /*
  if(fscanf(stdin, "%d %d\n", &number_of_nodes, &number_of_edges) != 2){
    exit(-1);
  }
  */

  if(number_of_nodes > MAX_NODES || number_of_edges > (MAX_PAGES * PAGE_SIZE)){
    printf("Graph size exceeds the maximum memory capacity.");
    return -1;
  }

  node_index = 0;
  page_index = 0;

#ifndef __STATIC__  
  node_array = (Node*) malloc(sizeof(Node) * MAX_NODES);
  if(node_array == NULL){
    printf("can allocate a memory for node_array.\n");
    exit(-1);
  }
  page_array = (Page*) malloc(sizeof(Page) * MAX_PAGES);
  if(page_array == NULL){
    printf("can allocate a memory for page_array.\n");
    exit(-1);
  }
  hashtable = (Node**) malloc(sizeof(Node*) * HASHTABLE_SIZE);
  if(hashtable == NULL){
    printf("can allocate a memory for hashtable.\n");
    exit(-1);
  }
#endif

  init_queue(&pqueue, MAX_NODES);

  Uint i;
  for(i=0; i<HASHTABLE_SIZE; i++){
    hashtable[i] = NULL;
  }

  Uint from, to, cost;

  while(fscanf(fp, "%d %d %d\n", &from, &to, &cost) == 3){
    add_edge(from, to, cost);
    //add_edge(to, from, cost); // undirected graph
  }

  /*
  while(fscanf(stdin, "%d %d %d\n", &from, &to, &cost) == 3){
    add_edge(from, to, cost);
    //add_edge(to, from, cost); // undirected graph
  }
  */

  printf("start:%d goal:%d\r\n", start, goal);
  printf("num_nodes:%d num_edges:%d\r\n", number_of_nodes, number_of_edges);

  struct timeval s, e;
  gettimeofday(&s, NULL);

  Uint sum_of_cost = find_shortest_path(start, goal);

  gettimeofday(&e, NULL);
  double exec_time = (e.tv_sec - s.tv_sec) + (e.tv_usec - s.tv_usec) * 1.0E-6;

  if(sum_of_cost < MAX_INT){
    walk_result(sum_of_cost, start, goal);
  }

  printf("exectuion time=%lf\n", exec_time);

#ifndef __STATIC__  
  free(node_array);
  free(page_array);
  free(hashtable);
#endif

  return 0;
}
